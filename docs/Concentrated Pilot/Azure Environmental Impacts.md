# Azure Environmental Impacts

## Document purpose

This document records the Azure environment issues that affected the OpenHands evaluation pilot, the troubleshooting performed, the evidence collected, and the resulting decision to move the evaluation workload to a local OpenHands deployment.

The purpose is to preserve the technical history, distinguish environmental failures from OpenHands evaluation results, and prevent the same infrastructure work from being repeated without new evidence.

## Executive summary

The evaluation environment depended on an Azure Virtual Network Gateway to provide point-to-site (P2S) VPN access to private Azure resources. The gateway repeatedly failed during provisioning and update operations with `VmssGatewayDeploymentFailed`.

The failure occurred in two materially different conditions:

1. An existing gateway failed during a P2S configuration update.
2. After the failed gateway was deleted, a newly created gateway failed during initial deployment before P2S was configured.

The repeated failure on a clean gateway significantly reduced the likelihood that the root cause was the P2S certificate, client address pool, OpenVPN selection, or BGP configuration. The available evidence points to a failure in the Azure VPN Gateway deployment layer or its dependent VM scale set provisioning.

Because the Azure subscription is a personal subscription without a paid technical support plan, direct escalation to an Azure support engineer was not readily available. Continued rebuilding would have added cost and schedule risk without producing evidence relevant to the OpenHands evaluation. The project therefore moved to running the open-source OpenHands code locally.

## Environment

- **Subscription ID:** `57ebfaff-6dc5-476d-84b3-99a5e1297d5a`
- **Resource group:** `brownfield-evals-experiment`
- **Region:** `westus`
- **Virtual network gateway:** `brownfield-evals-gateway`
- **Gateway type:** `Vpn`
- **VPN type:** `RouteBased`
- **SKU:** `VpnGw1AZ`
- **Gateway generation:** `Generation2`
- **Active-active mode:** Disabled
- **BGP:** Disabled
- **Intended P2S protocol:** OpenVPN
- **Intended P2S authentication:** Azure certificate authentication

## Intended architecture

The environment was intended to support the following access path:

```text
Local workstation
    -> Point-to-site VPN
    -> Azure Virtual Network Gateway
    -> Private Azure virtual network
    -> OpenHands and evaluation resources
```

The VPN gateway was infrastructure supporting the evaluation. It was not itself part of the OpenHands functionality or agent behavior being evaluated.

## Issues encountered

### 1. Azure VPN Gateway entered a failed provisioning state

The original virtual network gateway reported:

```text
ProvisioningState    GatewayType    VpnType     Sku
Failed               Vpn            RouteBased  VpnGw1AZ
```

The Azure Portal error was generic:

```text
The gateway deployment operation failed due to an intermittent error.
Please try again.
```

The Activity Log exposed the underlying error:

```text
ResourceOperationFailure
The resource operation completed with terminal provisioning state 'Failed'.

VmssGatewayDeploymentFailed
The gateway deployment operation failed due to an intermittent error.
Please try again.
```

### 2. Gateway reset was unavailable

A reset was attempted with Azure CLI. Azure rejected the operation because the gateway was already in a failed state:

```text
CannotResetGatewayInFailedState
Virtual network gateway is in failed state. Cannot reset failed gateway.
```

This prevented the normal reset-and-reapply recovery path.

### 3. A subsequent gateway write failed with the same backend error

The P2S client address pool was changed and the configuration was saved again to trigger another gateway write. The write reached the same terminal failure:

```text
VmssGatewayDeploymentFailed
The gateway deployment operation failed due to an intermittent error.
Please try again.
```

This showed that a second write did not recover the resource.

### 4. Clean gateway recreation also failed

The original gateway was deleted, despite the deletion operation taking significant time. A replacement gateway was then created with a deliberately minimal configuration:

- `VpnGw1AZ`
- Route-based VPN
- Generation 2
- Active-active disabled
- BGP disabled
- No initial P2S configuration

The replacement failed during initial provisioning before P2S configuration was added.

The deployment reported:

```text
ResourceDeploymentFailure
The resource write operation failed to complete successfully,
because it reached terminal provisioning state 'Failed'.
```

The top-level ARM deployment error did not identify a user-correctable configuration problem. It reported only that the resource had reached the terminal `Failed` state.

### 5. Azure Policy warning was not the blocking failure

The Activity Log showed an Azure Policy warning for:

```text
VPN gateways should use only Azure Active Directory authentication
for point-to-site users
```

The policy effect was `Audit`, not `Deny`, and the policy operation completed with status `Succeeded`. The warning therefore documented a security recommendation but did not block creation of the resource.

### 6. P2S address-pool uncertainty added troubleshooting overhead

The initial P2S client pool was:

```text
10.1.16.0/26
```

Because the full VNet address space was not present in the gateway export, overlap had to be considered as a possible cause. The pool was changed to:

```text
15.15.15.0/24
```

That change did not alter the deployment failure. In addition, `15.15.15.0/24` is public address space and is not a preferred long-term P2S client pool. If the Azure design is revisited, the client pool should use an unused RFC 1918 range, such as an available subnet within `172.16.0.0/12`, after checking for overlap with the VNet, local LAN, corporate networks, and any peered or routed networks.

### 7. Az PowerShell module failures interfered with diagnosis

The expected PowerShell query failed:

```text
Get-AzVirtualNetworkGateway:
GenericArguments[0],
'Microsoft.Azure.Management.Network.Models.SecurityRule',
on 'System.Nullable`1[T] MaxInteger[T](...)'
violates the constraint of type 'T'.
```

A related module-management problem had also occurred:

```text
Update-Module:
Module 'Az' was not installed by using Install-Module,
so it cannot be updated.
```

As a result, Azure CLI was used for gateway inspection and activity-log queries. This increased troubleshooting complexity because the environment contained an unhealthy or inconsistent Az PowerShell installation in addition to the gateway failure.

### 8. Certificate tooling required environment-specific workarounds

While creating the certificate chain for P2S authentication, the available OpenSSL executable was the ServiceNow Agent Client Collector embedded binary. It attempted to load an OpenSSL configuration from an incorrect path and produced errors similar to:

```text
Can't open "C:/ServiceNow/agent-client-collector/embedded/ssl/openssl.cnf"
for reading, No such file or directory
```

The correct executable path was under:

```text
C:\Program Files\ServiceNow\agent-client-collector\embedded\bin\openssl.exe
```

The `OPENSSL_CONF` environment variable was set for the PowerShell process to point to the correct configuration file. The root certificate, client private key, client CSR, signed client certificate, and password-protected PFX were subsequently created, and the client certificate was imported into the local certificate store.

Although certificate creation was ultimately completed, the gateway recreation later failed before P2S was configured. This indicates that certificate generation was not the cause of the clean gateway deployment failure.

### 9. Azure support access was constrained by the subscription

The affected subscription is a personal Azure subscription without a known paid technical support plan. The Azure Portal primarily presented self-help troubleshooting. Direct one-to-one technical support was not readily available.

The remaining free escalation route was Microsoft Q&A using the `azure-vpn-gateway` tag. Purchasing a support plan solely to investigate a blocked experimental environment would have added further cost.

## Failure timeline

### October 22, 2026, 16:14 UTC

An Azure Policy audit was recorded during a gateway write.

- **Correlation ID:** `1123fa9f-69b9-4d76-b20d-adb0cc764177`
- **Policy effect:** `Audit`
- **Policy operation status:** `Succeeded`
- **Interpretation:** Security recommendation only; not a deployment denial.

### October 22, 2026, 18:06 UTC

The original gateway write failed.

- **Correlation ID:** `314c49c3-e699-4005-a37b-bab664593b1f`
- **Operation ID:** `4538d0b8-3ba4-4354-8483-5fa2df3249fe`
- **Operation:** `Microsoft.Network/virtualNetworkGateways/write`
- **Result:** `Failed`
- **Underlying code:** `VmssGatewayDeploymentFailed`

### October 22, 2026, 18:55 UTC

A subsequent gateway write failed after changing the P2S address pool.

- **Correlation ID:** `70cd68d0-8067-4812-a550-410195176621`
- **Operation ID:** `86c2d656-967a-4dd6-977b-8aaafd5ff4f8`
- **Operation:** `Microsoft.Network/virtualNetworkGateways/write`
- **Result:** `Failed`
- **Underlying code:** `VmssGatewayDeploymentFailed`

### Replacement gateway deployment

The failed gateway was deleted and recreated with a minimal configuration and no initial P2S configuration.

- **Deployment name:** `Microsoft.VirtualNetworkGateway-20261022142019`
- **Target:** `brownfield-evals-gateway`
- **Result:** `ResourceDeploymentFailure`
- **Terminal provisioning state:** `Failed`

The clean deployment failure established that the problem was not limited to the original P2S configuration.

## Troubleshooting performed

The following actions were completed:

1. Verified the gateway type was `VPN`.
2. Verified the VPN type was `RouteBased`.
3. Verified the SKU was `VpnGw1AZ`.
4. Verified the gateway generation was `Generation2`.
5. Left active-active mode disabled.
6. Left BGP disabled because the design did not require dynamic route exchange.
7. Created a self-signed root certificate.
8. Created a client private key and CSR.
9. Signed the client certificate for client authentication.
10. Created a password-protected PFX.
11. Imported the client certificate into the local certificate store.
12. Uploaded root certificate public data to the P2S configuration.
13. Changed the P2S client address pool to eliminate overlap as a suspected cause.
14. Queried the gateway using Azure CLI after Az PowerShell cmdlets failed.
15. Reviewed Azure Activity Log administrative and policy events.
16. Attempted a gateway reset.
17. Retried a gateway write.
18. Deleted the failed gateway.
19. Recreated the gateway with minimal settings and without P2S configuration.
20. Confirmed that the clean gateway deployment also failed.

## Findings

### Confirmed

- The gateway type, route-based VPN type, SKU, generation, active-active setting, and BGP setting were internally coherent.
- The Azure Policy event was an audit, not a deny.
- The original gateway failed during a `Microsoft.Network/virtualNetworkGateways/write` operation.
- Azure refused to reset the original gateway because it was already in a failed state.
- A second write failed with the same `VmssGatewayDeploymentFailed` code.
- A newly created gateway failed before P2S was configured.
- The issue reproduced independently of the original P2S address pool and certificate configuration.

### Not confirmed

The available logs did not identify the underlying Azure platform cause. In particular, the evidence did not establish whether the failure was due to:

- Regional VPN Gateway capacity or allocation
- A transient or persistent West US platform condition
- Cleanup or residual state associated with backend gateway resources
- A subscription-specific service condition
- Another internal dependency of Azure VPN Gateway VM scale set provisioning

These possibilities require Azure-side diagnostics and should not be represented as confirmed root causes.

## Project and productivity impact

The Azure networking work displaced time that was intended for the OpenHands evaluation itself. The primary impacts were:

- Repeated gateway provisioning attempts
- Time spent waiting for long-running gateway creation and deletion operations
- Certificate-generation and local tooling workarounds
- Az PowerShell module troubleshooting
- Azure CLI and Activity Log investigation
- Rework caused by deleting and recreating the gateway
- Inability to obtain direct technical support through the personal subscription
- Increased Azure cost exposure while infrastructure remained deployed
- Increased risk to the evaluation deadline

Most importantly, the infrastructure work did not produce additional evidence about OpenHands agent behavior, evaluation quality, provider/model performance, or the evaluation framework.

## Decision

The Azure-hosted path is classified as **blocked by environment**, not as a failed OpenHands evaluation.

To protect the evaluation deadline and reduce further cost, the project will:

1. Stop rebuilding the Azure VPN Gateway.
2. Freeze or remove unnecessary Azure resources to prevent avoidable charges.
3. Run the open-source OpenHands code locally.
4. Reuse the established provider and model configuration where practical.
5. Continue the planned evaluation tasks, prompts, expected outcomes, and measurements locally.
6. Record hosting environment as a test condition so Azure infrastructure failures are not conflated with OpenHands evaluation results.

## Implications for evaluation results

The move from Azure-hosted OpenHands to local OpenHands changes the hosting environment but does not automatically invalidate evaluation results. The evaluation documentation should explicitly record:

- OpenHands version or commit
- Container image or build details
- Local operating system and container runtime
- Model provider and model deployment names
- OpenHands configuration relevant to agent behavior
- Workspace/repository version
- Evaluation task definitions and expected outcomes
- Any tools, network access, secrets, or filesystem permissions available to the agent
- Resource constraints that could affect runtime behavior

Results that depend on Azure private networking, Azure Files, VPN routing, managed identity, Azure-specific security boundaries, or cloud-hosting performance should be identified as not evaluated in the local run.

## Recommended future Azure re-entry criteria

Do not resume the Azure VPN Gateway path merely because more time is available. Resume only if at least one of the following is true:

- Azure Service Health identifies and resolves a relevant service issue.
- Microsoft Q&A or Azure Support provides a specific remediation for the recorded correlation IDs.
- A different region is acceptable for the entire dependent architecture.
- A paid support entitlement is available through a support plan, Visual Studio subscription benefit, partner benefit, or organizational subscription.
- The evaluation develops a requirement that can only be tested through the Azure-hosted topology.

Before another gateway attempt, verify the intended P2S address pool is private and non-overlapping, and verify that the local Az PowerShell installation is repaired or use Azure Cloud Shell/Azure CLI consistently.

## Support evidence package

Retain the following with this document:

- Exported gateway JSON: `gateway-current.json`
- Activity Log JSON for correlation ID `314c49c3-e699-4005-a37b-bab664593b1f`
- Activity Log JSON for correlation ID `70cd68d0-8067-4812-a550-410195176621`
- Policy audit JSON for correlation ID `1123fa9f-69b9-4d76-b20d-adb0cc764177`
- Deployment operation output for `Microsoft.VirtualNetworkGateway-20261022142019`
- Root certificate public file, stored securely as appropriate
- Client certificate and key artifacts, stored securely and excluded from general documentation repositories

> **Security note:** Do not commit private keys, PFX files, passwords, access tokens, identity claim blocks, or session data to source control. Activity Log exports should be reviewed and redacted before being shared publicly.

## Final status

- **Azure VPN Gateway:** Blocked; repeatable deployment failure
- **P2S VPN:** Not available because the gateway could not be provisioned successfully
- **Azure-hosted OpenHands evaluation:** Suspended
- **Local OpenHands evaluation:** Selected as the deadline-preserving path
- **Root cause:** Not established; Azure-side investigation required

## Addendum 2026-10-26: what was run after the move to local

- The baseline (`gpt-5.6-luna`) and injected (`gpt-4.1-nano`) conditions, and the framework spike, were run on local OpenHands Agent Server 1.58.1 on 2026-10-26. The as-run environment and which controls no longer apply are in the [charter addendum](./experiment-charter-2026-10-19.md). Azure runs from 10-19 to 10-21 (Agent Server 1.54.0) remain as recorded and are not pooled with the local runs.
- The Azure-only effects listed above as "not evaluated in the local run" are still not evaluated.
- **Azure teardown is not recorded here.** `config/AzResources-ShutDown.ps1` was edited to set and verify the subscription before shutdown, but whether the resources (container, firewall, gateway, storage) were stopped or deleted is not documented. The charter notes the infrastructure, not model use, is the main cost driver. Record the shutdown outcome and date once done.
- The support evidence files named above (such as `gateway-current.json`, `config/az-error.json`) are untracked in Git. Review them for sensitive content before committing, as the security note says. This document also names the subscription ID and resource names; confirm that is acceptable before sharing it outside the project.
