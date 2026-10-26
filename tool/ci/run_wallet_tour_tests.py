"""Finite memory-only policy tests before hosted SDK allocation."""

from pathlib import Path
import unittest

from .run_debug_tests import execute_suite


def main():
    directory = str(Path(__file__).absolute().parents[2] / 'test/ci')
    suite = unittest.TestLoader().discover(directory, pattern='test_windows_wallet_tour.py')
    return execute_suite(suite, scope='wallet_tour_inmemory_cases',
                         title='Wallet tour policy tests')


if __name__ == '__main__':
    raise SystemExit(main())
