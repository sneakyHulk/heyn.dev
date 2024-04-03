---
title: "Reflection in C++"
date: 2022-09-22T00:02:18Z
draft: false
websiteURL: https://heyn.dev
websiteName: heyn.dev
---

Reflection means in the context of programming that a program knows its own structure and/or can change it.
Reflection allows for example in object-oriented programming the query of information at runtime about the classes.
In the case of a class, this includes the name of the class, the defined fields and methods.
C++ has no such features.
But there are libraries that can emulate such behavior with some tricks.
I will briefly present some libraries that I used in the past:

## visit_struct

[**visit_struct**](https://github.com/garbageslam/visit_struct) is a header-only library providing structure visitors.
You can define classes as visitable and the library will then provide iterators over the defined members that contain the member's name and value.
Of course, to be accessible, the members must be public.
To define classes as visitable, there is a handy macro.
```c++
struct s1 {
    float m1[42];
    int m2;
    std::vector<double> m3;
};

VISITABLE_STRUCT(s1, m1, m2, m3);
```
This will enable you to write the following:
```c++
visit_struct::for_each(s1, [](char const* name, auto const& value) {
    std::cout << name << ": " << value << std::endl;
});
```
There are other handy functions, like
```c++
s1 test;
visit_struct::get<i>(test);
```
to get the i-th member of an object of a visitable class and
```c++
visit_struct::traits::is_visitable<s1>::value
```
to test if a class is visitable.
Especially the last one is useful, as it allows to find and access nested visitable classes in other visitable classes.
All in all, a pretty neat library.

## YAS - Yet Another Serialization

In most cases you don't need to loop over the members of a class or retrieve the name of a particular class member, oftentimes you just want to serialize data to store it or send it elsewhere.
For this task, the serialization library [**yas**](https://github.com/niXman/yas) proves useful.
Here you define the class you want to be serializable, similar to the library above.
```c++
struct s1 {
    float m1[42];
    int m2;
    std::vector<double> m3;
};

YAS_DEFINE_INTRUSIVE_SERIALIZE("s1", s1, m1, m2, m3);
```
After that it is possible to write to and read from memory or a file.
You can also choose between binary for binary output, text for text-based output and json for json output.
A write to file and a read from the same file would look something like the following:
```c++
s1 test;

yas::file_ostream os("test.bin");
yas::binary_oarchive<yas::file_ostream> oa(os);

oa & test;

yas::file_istream is("test.bin");
yas::binary_iarchive<yas::file_istream> ia(is);

s1 test2;

ia & test2;

assert(test.m1 == test2.m1 && test.m2 == test2.m2 && test.m3 == test2.m3);
```
Even nested classes can be serialized without problems if the serialization macro is set for all classes and very commonly used STL containers like std::array and std::vector work flawlessly.
Easy to handle!

## alpaca

[**alpaca**](https://github.com/p-ranav/alpaca) is the latest addition to do serialization in C++.
It doesn't require a macro to define classes, and even provides variable-length encoding, type hashing, and versioning of data structures, as well as integrity checking out of the box.
Seems perfect.
The only downside is that you can't use C-style arrays as easily.
This is really unfortunate, but STL containers are perfectly supported.
Here is an example:
```c++
struct s1 {
    std::array<float, 42> m1;
    int m2;
    std::vector<double> m3;
};

std::vector<uint8_t> bytes;
auto bytes_written = alpaca::serialize(s, bytes);

std::error_code ec;
auto bytes_recovered = alpaca::deserialize<s1>(bytes, ec);
assert((bool)ec == false);
```
