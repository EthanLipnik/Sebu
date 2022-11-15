# Sebu

Easy caching for codable objects.

### How does it store?

Sebu uses JSON to store objects in the app's cache directory.

### Usage

#### Save

Save object

```swift
let tweets = [Tweet()] // Your own object(s)
try Sebu.default.set(tweets,
              withName: "homeTimeline") // Your own cache name (overwrites by default)
```

Save object with expiration

```swift
try Sebu.default.set(tweets,
              withName: "homeTimeline",
              expiration: Calendar.current.date(byAdding: .minute, value: 5, to: Date())) // Expires in 5 minutes from now
```

#### Get

```swift
if let cache: [Tweet] = try? Sebu.default.get(withName: "homeTimeline") {
  self.tweets = cache
}
```

#### Clear cache

All cache

```swift
Sebu.default.clearAll()
```

Clear certain object

```swift
Sebu.default.clear("homeTimeline")
```

