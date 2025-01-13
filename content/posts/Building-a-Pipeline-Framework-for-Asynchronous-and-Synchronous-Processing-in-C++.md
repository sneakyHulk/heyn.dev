---
title: "Building a Pipeline Framework for Asynchronous and Synchronous Processing in C++"
date: 2024-12-26T00:00:19Z
draft: true
websiteURL: https://heyn.dev
websiteName: heyn.dev
---

In areas such as sensor data processing and data streaming, creating flexible and efficient pipelines is essential.
This pipeline pattern allows various processing stages to be linked, with each stage executing a specific operation.
The core idea behind the pipeline pattern is the separation of concerns: different "nodes" in the pipeline perform
specific tasks, and data flows through these nodes in a manner that allows for both synchronous and asynchronous
execution.
In this blog post, we will explore my implementation of a pipeline system using C++.

## The Pipeline Node Classes

A node in the pipeline is essentially a unit of work.
There are three classes of nodes.

- The **Pusher** class serves as an starting point of a pipeline, responsible for generating and forwarding data to
  downstream nodes.
- The **Processor** class responsible for transforming the incoming data into output data.
- The **Runner** class serves as an endpoint of a pipeline, responsible for presenting the incoming data or performing
  actions on the incoming data outside the pipeline.

The node classes are connected together.


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