def add(a, b):
    r = a + b
    return r


class User:
    def __init__(self, name, age):
        self.name = name
        self.age = age


def main():
    u = User("Myo", 29)
    total = 0
    for i in range(5):
        total += add(i, total)
    print("hi", u.name, total)
    print("done")


if __name__ == "__main__":
    main()
