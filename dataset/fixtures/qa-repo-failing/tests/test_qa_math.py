import unittest

from qa_math import add, subtract


class MathTests(unittest.TestCase):
    def test_addition(self):
        self.assertEqual(add(2, 3), 5)

    def test_subtracts_positive_numbers(self):
        self.assertEqual(subtract(7, 2), 5)


if __name__ == "__main__":
    unittest.main()
