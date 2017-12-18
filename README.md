# MessageListener
A tool for monitoring objc message called.

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods](https://img.shields.io/cocoapods/v/MessageListener.svg)](https://github.com/TangentW/MessageListener)

## Guide & Blog
[Tangentw - 基于isa-swizzling实现消息监听,扩展响应式框架](http://www.jianshu.com/p/86f6059af7a0)

## Installation
### Carthage
Add `MessageListener` in your `Cartfile`:

```
github "TangentW/MessageListener"
```

Run `carthage update` to build the framework and drag into your project.

### Cocoapods
Add `MessageListener` in your `Podfile`:

```
use_frameworks!

pod "MessageListener"
```

Run the following command:

```
$ pod install
```

### Manually
1. Download the source code.
2. Drag files **NSObject+Listener.h** and **NSObject+Listener.m** into your project.

## Usage
Use method `listen`.

### For normal method
#### Objc
```Objc
[self listen: @selector(touchesBegan:withEvent:) with:^(NSArray * _Nonnull parameters) {
	NSLog(@"Touches began");
}];
```

#### Swift
```Swift  
listen(#selector(ViewController.touchesBegan(_:with:))) { _ in
	print("Touches began")
}
```

### For protocol method
#### Objc
```Objc
[self listen: @selector(tableView:didSelectRowAtIndexPath:) in:@protocol(UITableViewDelegate) with:^(NSArray * _Nonnull parameters) {
	if (parameters.count != 2) return;
	NSIndexPath *indexPath = parameters[1];
	NSLog(@"Did selected row %ld", (long)indexPath.row);
}];
```

#### Swift
```Swift
listen(#selector(UITableViewDelegate.scrollViewDidScroll(_:)), in: UITableViewDelegate.self).subscribe(next: { parameters in
	guard let tableView = parameters.first as? UITableView else { return }
		print(tableView.contentOffset.y)
})
_tableView.delegate = self
```

## License
The MIT License (MIT)


