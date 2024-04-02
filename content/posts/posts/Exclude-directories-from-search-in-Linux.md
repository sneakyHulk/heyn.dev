---
title: "Exclude Directories From Search in Linux"
date: 2022-01-20T07:57:53Z
draft: false
comments: false
images:
---

We're all familiar with the scenario, one makes a mistake with the path input and already the file is lost in the file system.
Now you want to find the lost file again...

``` bash
find / -name lost_file
```

Now, however, like me, you have a server with 12 TB of attached ZFS storage and you don't want the find command to search it as well.
You can do this as follows:

``` bash
find / ! \( -path '/zfs_mount' -prune \) -name lost_file
```

By the way, if you want to omit e.g. another large directory now, the sections can be lined up:

``` bash
find / ! \( -path '/zfs_mount' -prune \) ! \( -path '/big_directory' -prune \) -name lost_file
```
