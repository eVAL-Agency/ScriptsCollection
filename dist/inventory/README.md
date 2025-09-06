# Inventory Collection Scripts

Scripts that collect device asset inventory information to be sent to an external database.

Provides support for SuiteCRM (fork of SugarCRM) and [Grist](https://www.getgrist.com/).

* Grist: [Windows](windows_inventory_device_to_grist.ps1) [Linux](linux_inventory_device_to_grist.py)
* SuiteCRM: [Windows](windows_inventory_device_to_suitecrm.ps1) [Linux](linux_inventory_device_to_suitecrm.py)

## Grist

Requires use of [Grist Middleware](https://github.com/eVAL-Agency/Grist-Scripts) scripts to facilitate communication
with the database.
Unlike the SuiteCRM version, the Grist version sends all raw data to the middleware handler
where that script determines whether to create a new record or update an existing one.

### Grist Setup

For tracking and basic authentication, Grist will need a `Token` field in the `Account` table
which is a random and unique string to be sent to the device.

This can be done with a trigger formula set on `Apply to new records` such as:

```python
import os
return os.urandom(15).hex()
```

### Tactical Setup

Create the custom fields in TacticalRMM (Settings -> Global Settings -> Custom Fields)

* Client-level: `grist_url` - the URL with https prefix of your Grist installation eg: `https://grist.yourdomain.com`
* Client-level: `grist_account` - text field with no default value

Then under each `Client`, set the value of the account `Token` field for that specific client to `grist_account`.


## SuiteCRM

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
* Admin -> Security Groups -> Create group for device group
* Admin -> OAuth2 Clients -> New Client Credentials Client (with service user assigned)

The `client_id` will be the ID listed on the view page of the token
and the `client_secret` will be whatever secret entered when creating the token.

It is recommended to create a dedicated service-level user account for this script.

Use roles to limit service-level access to only the necessary modules, ("Devices" if using the supplied module).

Recommended Roles:

* All Modules: Access - Disabled
* All Modules: * - None
* Devices: Access - Enabled
* Devices: Edit - Group
* Devices: List - Group
* Devices: View - Group

### Tactical Setup

Create the custom fields in TacticalRMM (Settings -> Global Settings -> Custom Fields)

* Client-level: `crm_url` - the URL (no https prefix), of your SuiteCRM installation
* Client-level: `crm_client_id` - the OAuth2 client ID
* Client-level: `crm_client_secret` - the OAuth2 client secret

