import pytest
from app import add


def test_add():
    assert add(2, 3) == 5


def test_fails():
    assert add(2, 2) == 5


@pytest.mark.parametrize("a,b,want", [(1, 1, 2), (2, 2, 5)])
def test_param(a, b, want):
    assert add(a, b) == want


class TestGroup:
    def test_in_class(self):
        assert add(0, 0) == 0
