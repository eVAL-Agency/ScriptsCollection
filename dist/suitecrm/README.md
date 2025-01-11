# SuiteCRM Scripts

## Device Inventory Collection

In order to track device asset info from within SuiteCRM, you must install a compatible module for device tracking.

An available module is available at (@TODO).

### Setup OAuth for SuiteCRM

To generate auth tokens, ensure to follow the recommendations from
https://docs.suitecrm.com/developer/api/developer-setup-guide/json-api/

Notably:

```bash
cd {{suitecrm.root}}/Api/V8/OAuth2
openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
chmod 600 private.key public.key
# and ensure it's owned by the web user, www-data or whatever it may be
```

Once SuiteCRM is ready to accept OAuth auth, setup a new token:

### User Setup

* Admin -> Users -> Create service user as necessary
* Admin -> OAuth2 Clients -> New Client Credentials Client (with service user assigned)

The `client_id` will be the ID listed on the view page of the token
and the `client_secret` will be whatever secret entered when creating the token.

It is recommended to create a dedicated service-level user account for this script.
This is because the API key is deployed to the remote agent for data submission.

Use roles to limit service-level access to only the necessary modules, ("Devices" if using the supplied module).

Recommended Roles:

* All Modules: Access - Disabled
* All Modules: * - None
* Devices: Access - Enabled
* Devices: Edit - All (everything else None)

### Tactical Setup

Create the custom fields in TacticalRMM (Settings -> Global Settings -> Custom Fields)

* Client-level: `crm_url` - the URL (no https prefix), of your SuiteCRM installation
* Client-level: `crm_client_id` - the OAuth2 client ID
* Client-level: `crm_client_secret` - the OAuth2 client secret
* Agent-level: `crm_id` - the SuiteCRM ID of the device; no default value but should be set manually

### Device Setup

Create a device in SuiteCRM and copy/paste the object ID into the `crm_id` field in TacticalRMM.

(Retrievable by viewing the device and grabbing the `record=...` part.)
