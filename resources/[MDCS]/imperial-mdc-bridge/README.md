# Imperial CAD <-> LASD MDC Bridge

Wrapper script that intercepts ImperialCAD API calls and automatically syncs them to the web MDC.

## Purpose

This bridge sits between your framework and ImperialCAD, ensuring that:
1. All 911 calls are automatically sent to the web MDC
2. Manual calls created by officers sync to MDC
3. Unit attachments update the MDC in real-time
4. Deleted calls are removed from MDC

## How It Works

Instead of calling ImperialCAD directly:
```lua
-- OLD WAY (Don't do this anymore)
exports['ImperialCAD']:Create911Call(data, callback)
```

Other resources should now call the bridge:
```lua
-- NEW WAY (Automatic MDC sync)
exports['imperial-mdc-bridge']:Create911Call(data, callback)
```

The bridge:
1. Calls ImperialCAD normally
2. Waits for successful response
3. Triggers `mdc:sync911Call` event with formatted data
4. auto-call-sync picks up the event and sends to web MDC

## Installation

1. **Already done** - This resource is in `[MDCS]` folder

2. **Add to server.cfg:**
   ```
   ensure ImperialCAD
   ensure auto-call-sync
   ensure imperial-mdc-bridge
   ```

3. **Update your framework/resources** to use bridge exports instead of ImperialCAD directly

## Wrapped Functions

### Create911Call
```lua
exports['imperial-mdc-bridge']:Create911Call({
    name = "John Doe",
    street = "Main St",
    crossStreet = "2nd Ave",
    postal = "102",
    city = "Los Santos",
    county = "Los Santos County",
    info = "Disturbance at the location"
}, function(success, res)
    -- Your callback
end)
```

### CreateCall (Manual)
```lua
exports['imperial-mdc-bridge']:CreateCall({
    users_discordID = "123456789",
    street = "Main St",
    crossStreet = "2nd Ave",
    postal = "102",
    city = "Los Santos",
    county = "Los Santos County",
    info = "Officer initiated call",
    nature = "Traffic Stop",
    status = "PENDING",
    priority = 2
}, function(success, res)
    -- Your callback
end)
```

### AttachCall
```lua
exports['imperial-mdc-bridge']:AttachCall({
    users_discordID = "123456789",
    callnum = 12847
}, function(success, res)
    -- Your callback
end)
```

### DeleteCall
```lua
exports['imperial-mdc-bridge']:DeleteCall({
    callId = "ABC123",
    discordId = "123456789"
}, function(success, res)
    -- Your callback
end)
```

## Testing

Run from **server console**:
```
testbridge
```

This creates a test 911 call and syncs it to your web MDC.

## Migration Guide

If you have existing resources calling ImperialCAD:

1. **Find all instances:**
   ```bash
   grep -r "exports\['ImperialCAD'\]" /path/to/resources/
   ```

2. **Replace with bridge:**
   ```lua
   -- Before
   exports['ImperialCAD']:Create911Call(data, callback)

   -- After
   exports['imperial-mdc-bridge']:Create911Call(data, callback)
   ```

3. **Restart server** to load the bridge

## Troubleshooting

**Q: Calls not appearing in MDC?**
- Check that all 3 resources are started: `ensure ImperialCAD`, `ensure auto-call-sync`, `ensure imperial-mdc-bridge`
- Run `testbridge` in console to verify connection
- Check server console for error messages

**Q: ImperialCAD still works but MDC doesn't update?**
- Resources are probably still calling `ImperialCAD` directly instead of the bridge
- Migrate resources to use bridge exports

**Q: How to verify the bridge is working?**
- Run `testbridge` in console
- Check server logs for `[IMPERIAL-MDC-BRIDGE]` messages
- Check web MDC for test call (CPT + random number)

## Dependencies

- ImperialCAD (official resource)
- auto-call-sync (our MDC sync resource)

## Architecture

```
Your Framework/Resource
    ↓
imperial-mdc-bridge (this)
    ↓
    ├─→ ImperialCAD API → ImperialCAD Website
    └─→ TriggerEvent('mdc:sync911Call')
            ↓
        auto-call-sync
            ↓
        Web MDC API → LASD MDC Interface
```

## Version History

**v1.0.0** - Initial release
- Wraps Create911Call, CreateCall, AttachCall, DeleteCall
- Automatic MDC sync for all call operations
