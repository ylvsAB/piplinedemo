import pytest

from pipeline_demo import add, divide, multiply, subtract


@pytest.mark.parametrize(
    ("a", "b", "expected"),
    [(1, 2, 3), (-1, 1, 0), (0.1, 0.2, pytest.approx(0.3))],
)
def test_add(a, b, expected):
    assert add(a, b) == expected


def test_subtract():
    assert subtract(5, 3) == 2


def test_multiply():
    assert multiply(4, 2.5) == 10


def test_divide():
    assert divide(9, 2) == 4.5


def test_divide_by_zero():
    with pytest.raises(ValueError, match="除数不能为 0"):
        divide(1, 0)
