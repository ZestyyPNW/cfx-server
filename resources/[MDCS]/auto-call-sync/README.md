# LASD MDC Auto Call Sync

Automatically synchronizes 911 calls and updates from ImperialCAD to your LASD web MDC.

## Features

- ✅ Converts ImperialCAD call format to LASD MDC format
- ✅ Automatic radio code mapping based on call nature
- ✅ Real-time call status updates
- ✅ Supports all LASD MDC display formats (Index, Detail, Default Window)
- ✅ Configurable webhooks to web MDC
- ✅ Debug mode for troubleshooting

## Installation

1. **Add to server.cfg:**
   ```
   ensure auto-call-sync
   ```

2. **Configure the script:**
   Edit `config.lua` and update:
   ```lua
   Config.MDC_URL = "https://your-domain.com/lasd/mdc/api/newCall"
   Config.MDC_API_KEY = "your_secure_api_key"
   ```

3. **Set up web MDC endpoint:**
   Your web MDC needs an API endpoint at `/api/newCall` that accepts POST requests with the LASD call format.

## Configuration

### config.lua

```lua
Config.MDC_URL -- Your web MDC API endpoint
Config.MDC_API_KEY -- API key for securing the webhook
Config.Debug -- Enable/disable debug logging
Config.AutoSync -- Enable/disable automatic syncing
Config.RadioCodes -- Map call types to LASD radio codes
Config.StatusMap -- Map ImperialCAD statuses to LASD codes
```

## Usage

### Automatic Syncing

Once configured, the script listens for these events:
- `mdc:sync911Call` - New 911 call created
- `mdc:syncCallUpdate` - Call status/details updated

### Manual Testing

Run from **server console**:
```
testmdcsync
```

This sends a test call (417 245 510 - shooting/road rage) to your MDC.

## Integration with ImperialCAD

### Option 1: Modify ImperialCAD Exports

Edit `/resources/[Imperial]/ImperialCAD/utils/imperialEmergency.lua`:

In the `Create911Call` function, add after line 67:
```lua
performAPIRequest("https://imperialcad.app/api/1.1/wf/911", data, headers, function(success, res)
    if callback then callback(success, res) end

    -- NEW: Trigger MDC sync
    if success then
        local response = json.decode(res)
        TriggerEvent('mdc:sync911Call', {
            callId = response.response.callId,
            callnum = response.response.callnum,
            nature = data.info, -- Will be mapped to radio codes
            priority = 1, -- Default to P1 for 911 calls
            status = "PENDING",
            street = data.street,
            crossStreet = data.cross_street,
            city = data.city,
            county = data.county,
            postal = data.postal,
            info = data.info,
            name = data.name,
            phone = data.phone or "(000) 000-0000",
            units = {}
        })
    end
end)
```

### Option 2: Wrapper Resource

Create a new resource that wraps ImperialCAD exports and triggers MDC sync events. This keeps ImperialCAD unmodified.

Example in your framework's server file:
```lua
-- When your framework creates a 911 call
exports['ImperialCAD']:Create911Call(callData, function(success, res)
    if success then
        local response = json.decode(res)

        -- Trigger MDC sync
        TriggerEvent('mdc:sync911Call', {
            callId = response.response.callId,
            callnum = response.response.callnum,
            nature = callData.info,
            priority = 1,
            status = "PENDING",
            street = callData.street,
            crossStreet = callData.crossStreet,
            city = callData.city,
            county = callData.county,
            postal = callData.postal,
            info = callData.info,
            name = callData.name,
            units = {}
        })
    end
end)
```

## Web MDC API Endpoint

Your web MDC needs to handle POST requests at `/api/newCall`:

### Expected Request Format

```json
{
    "time": "1445",
    "tag": "CPT12847",
    "code": "417 245 510",
    "status": "(D)",
    "units": "1A52 1A53 1A91 1L21",
    "detailLines": [
        "CPT12847  417 245 510",
        "(D) 1A52 1A53 1A91 1L21",
        "15200 PACIFIC COAST HWY / CORRAL CANYON RD, MALIBU",
        "RMK VICTIM SHOT DURING ROAD RAGE INCIDENT, SUSPECT FLED NB IN BLACK DODGE CHARGER"
    ],
    "messageText": "INCIDENT RECORD 2025-11-06    1445\n...",
    "sonoranCallId": "TEST123ABC",
    "isAttached": false,
    "priority": 1,
    "postal": "102"
}
```

### Sample Node.js Endpoint (Express)

```javascript
// In your /var/www/scrp/lasd/mdc/server.js or similar

app.post('/api/newCall', (req, res) => {
    const apiKey = req.headers['x-api-key'];

    // Verify API key
    if (apiKey !== process.env.MDC_API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    const lasdCall = req.body;

    // Store in database or broadcast to connected MDC clients
    // Example: Socket.io broadcast
    io.emit('newCall', lasdCall);

    console.log('New call received:', lasdCall.tag);
    res.json({ status: 'success', message: 'Call added to MDC' });
});
```

## Call Data Flow

```
911 Call Created (in-game)
    ↓
ImperialCAD API (https://imperialcad.app/api/1.1/wf/911)
    ↓
Returns: { callId: "ABC123", callnum: 12847 }
    ↓
TriggerEvent('mdc:sync911Call', imperialCallData)
    ↓
auto-call-sync converts to LASD format
    ↓
POST to Config.MDC_URL
    ↓
Web MDC displays call in dispatch index
```

## Radio Code Mappings

The script automatically maps call types to LASD radio codes:

| Call Type | Radio Code |
|-----------|------------|
| Disturbance | 415 |
| Assault | 245 |
| Robbery | 211 |
| Shooting | 417 245 |
| Traffic Stop | 510 |
| Person With Gun | 417 |
| Medical | 10-52 |
| Fire | 10-70 |
| Unknown | 11-99 |

Edit `Config.RadioCodes` in `config.lua` to customize.

## Troubleshooting

1. **Calls not appearing in MDC?**
   - Check `Config.AutoSync = true`
   - Verify `Config.MDC_URL` is correct
   - Check server console for error messages
   - Enable `Config.Debug = true` for detailed logs

2. **Radio codes wrong?**
   - Update `Config.RadioCodes` mappings in config.lua

3. **Test the connection:**
   - Run `testmdcsync` in server console
   - Check web MDC for test call (CPT12847)

## Support

For issues, check:
- `/root/LASD_MDC_FORMAT_REFERENCE.md` - MDC format specifications
- `/root/IMPERIAL_CAD_API_REFERENCE.md` - ImperialCAD API documentation

## Version History

**v1.0.0** - Initial release
- Basic call sync functionality
- Radio code mapping
- LASD format conversion
