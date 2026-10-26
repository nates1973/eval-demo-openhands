$env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
$py=(Resolve-Path '.\.venv-frameworks\Scripts\python.exe').Path
$env:DEEPEVAL_TELEMETRY_OPT_OUT='YES';$env:PROMPTFOO_PYTHON=$py;$env:PROMPTFOO_DISABLE_TELEMETRY='1';$env:PROMPTFOO_DISABLE_UPDATE='1'
$L='results\frameworks\spike-log.txt'
function stamp($m){"$(Get-Date -Format o) $m"|Add-Content $L}
stamp 'pytest start'; & $py -m pytest frameworks/pytest_harness/test_pilot.py -q -p no:cacheprovider --junitxml=results/frameworks/pytest-junit.xml *>> $L; stamp 'pytest done'
stamp 'deepeval start'; & $py -m pytest frameworks/deepeval_spike/test_pilot_deepeval.py -q -p no:cacheprovider --junitxml=results/frameworks/deepeval-junit.xml *>> $L; stamp 'deepeval done'
foreach($p in 'gpt-5.6-luna','gpt-4.1-nano'){stamp "inspect $p start"; & $py -m inspect_ai eval frameworks/inspect-ai/pilot_task.py -T profile=$p --epochs 3 --model mockllm/model --max-samples 1 --max-tasks 1 --log-dir results/frameworks/inspect/logs *>> $L; stamp "inspect $p done"}
stamp 'promptfoo start'; Push-Location frameworks\promptfoo; npx --yes promptfoo@0.125.1 eval -c promptfooconfig.yaml --repeat 3 -j 1 --no-cache --no-progress-bar --no-share -o ..\..\results\frameworks\promptfoo-results.json *>> ..\..\$L; Pop-Location; stamp 'promptfoo done'
stamp 'ALL DONE'
