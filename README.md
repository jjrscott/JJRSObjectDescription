# JJRSObjectDescription
Detailed object descriptions using NSCoder

`JJRSObjectDescription` uses NSCoder to traverse objects and return something like the default description.

For example, instead of writing:

```objc
NSLog(@"%@", yourObject);
```

use:

```objc
NSLog(@"%@", [JJRSObjectDescription descriptionForObject:yourObject]);
```

It's that easy.

Note that the output from  `-[JJRSObjectDescription descriptionForObject:]` is for humans only, just like `-[NSObject description]`.
