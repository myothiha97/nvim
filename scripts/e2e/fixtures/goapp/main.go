package main

import (
	"fmt"
	"os"
	"sync"

	"example.com/goapp/calc"
)

type User struct {
	Name  string
	Age   int
	Tags  []string
	Meta  map[string]int
	Inner *Inner
}

type Inner struct {
	Note string
}

func greet(u User) string {
	msg := fmt.Sprintf("hi %s (%d)", u.Name, u.Age)
	return msg
}

func worker(id int, wg *sync.WaitGroup, out chan<- int) {
	defer wg.Done()
	v := calc.Square(id)
	out <- v
}

func main() {
	u := User{Name: "Myo", Age: 29, Tags: []string{"go", "nvim"}, Meta: map[string]int{"a": 1, "b": 2}, Inner: &Inner{Note: "deep"}}
	total := 0
	for i := 0; i < 5; i++ {
		total += calc.Add(i, total)
	}
	s := greet(u)
	fmt.Println(s, total)

	var wg sync.WaitGroup
	out := make(chan int, 3)
	for i := 1; i <= 3; i++ {
		wg.Add(1)
		go worker(i, &wg, out)
	}
	wg.Wait()
	close(out)
	sum := 0
	for v := range out {
		sum += v
	}
	fmt.Println("sum", sum)
	if len(os.Args) > 1 && os.Args[1] == "panic" {
		var m map[string]int
		m["x"] = 1
	}
	fmt.Println("done")
}
