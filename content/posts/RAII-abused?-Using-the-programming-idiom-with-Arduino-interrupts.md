---
title: "RAII Abused? Using the Programming Idiom With Arduino Interrupts"
date: 2022-08-17T00:00:19Z
draft: false
comments: false
images:
---

## What is RAII?

Resource acquisition is initialization abbreviated RAII denotes a programming idiom for managing resources.
Here, the allocation of resources is tied to the constructor call of the class and the release of resources is tied to its destructor call, which ensures that they are actually released.
The automatic release is triggered by leaving the scope at the end of the block or when an exception is thrown by returning to the caller.

The prominent example of RAII is std::lock_gurad:
``` c++
void WriteToFile(const std::string& message) {
  static std::mutex mutex;

  std::lock_guard<std::mutex> lock(mutex);

  std::ofstream file("example.txt");
  if (!file.is_open()) {
    throw std::runtime_error("unable to open file");
  }

  file << message << std::endl;
}
```
Regardless of the exception, this code releases the file resource and thus the mutex upon completion so that it can be rewritten.

## RAII for Arduino interrupts

In Arduino programming it is not common to use exceptions.
Therefore this idiom is quite useless.
But it has another interesting feature: You can execute a function after a return statement.
This is sometimes quite useful.
I use it for example to enable and disable interrupts in some interrupt service routines.
Here sometimes several other interrupts have to be disabled to avoid problems with the execution flow.
Also there are often several return statements to terminate the interrupt service routine.
Enabling the interrupts each time beforehand is redundant and tends to confuse.
It is simpler to use RAII as follows:
``` c++
struct interrupt_guard {
    interrupt_guard() { noInterrupts(); }
    ~interrupt_guard() { interrupts(); }
}

void ISR() { // interrupt service routine
    interrupt_guard guard;

    // time critical code here
}
```
