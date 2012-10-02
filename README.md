# Introduction
This is my attempt at a implementation of the Object Composition Pattern in Objective-C. It is intended to be as Lightweight and Simple as possible, whilst requiring minimal configuration.

# Usage
 Just add the Classes to your XCode project and add an import for NSObject+LLComposite.h in any classes that you wish to use composition. The easiest way of using this in all of your classes without #imports in each of them is to add the import in the prefix header.
 
 A component can be any Instance of an Object and added via the -addComponent: Method. This will add the component to each instance individually. If you wish to add a component to all instances, I suggest that you do this in the constructor of the object.
 
You can adopt to explicity use the class LLCompositeForwarder to perform forwarding of methods, however 
 
# Gotchas
 If you are using the category forwarding then make sure to never override any method ending in __original, _triage or _composite. These are the methods that the category uses in swizzling so that the original implementation of forwarding methods are preserved.
 
I have not tested the performance. For each Composite object that adds a Component with addComponent: One Class and One Mutable Dictionary will be created. This is on a Per-Instance basis. If you think that this is too much of an overhead this (version) of the library is probably not for you. 

Performance will also be affected if there are Components that have the same selector. Each selector will be called once per Component instance. This requires that the use of NSInvocation which has additional overhead when compared to a call propogated through the use of the fast forwarding method (this occurs when there is only **one** component matching the selector).
 
# Implementation Detail
Objective-C is a great language for implementing Composition as the Forwarding of Messages is a language-level feature. class for object compositio	n, it uses Objective-C Message Forwarding to allow 

# TODO
- Proper (Unit) Testing
- CococaPod
- Performance Testing
- Dynamic Classes for Composites who have *identical* components 

# Licence