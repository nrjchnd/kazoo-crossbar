### Ledgers

#### About Ledgers

#### Schema

ledgers document



Key | Description | Type | Default | Required
--- | ----------- | ---- | ------- | --------
`account.id` | Account ID | `string()` |   | `false`
`account.name` | Account name | `string()` |   | `false`
`account` | Account info | `object()` |   | `false`
`amount` | Ledger amount | `integer()` |   | `false`
`description` | Useful description for ledger | `string()` |   | `false`
`metadata` | Metadata for ledger document | `object()` |   | `false`
`period.end` | Period end | `integer()` |   | `false`
`period.start` | Period start | `integer()` |   | `false`
`period` | Period of ledger | `object()` |   | `false`
`source.id` | Source ID | `string()` |   | `true`
`source.service` | Source service | `string()` |   | `true`
`source` | Origin of ledger | `object()` |   | `true`
`usage.quantity` | Usage quantity | `integer()` |   | `true`
`usage.type` | Usage type | `string()` |   | `true`
`usage.unit` | Usage unit | `string()` |   | `true`
`usage` | Usage for ledger | `object()` |   | `true`



#### Fetch

> GET /v2/accounts/{ACCOUNT_ID}/ledgers

```shell
curl -v -X GET \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/ledgers
```

#### Fetch

> GET /v2/accounts/{ACCOUNT_ID}/ledgers/{LEDGER_ID}

```shell
curl -v -X GET \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/ledgers/{LEDGER_ID}
```

#### Create

> PUT /v2/accounts/{ACCOUNT_ID}/ledgers/debit

```shell
curl -v -X PUT \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/ledgers/debit
```

#### Create

> PUT /v2/accounts/{ACCOUNT_ID}/ledgers/credit

```shell
curl -v -X PUT \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/ledgers/credit
```

#### Fetch

> GET /v2/accounts/{ACCOUNT_ID}/ledgers/{LEDGER_ID}/{LEDGER_ENTRY_ID}

```shell
curl -v -X GET \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/ledgers/{LEDGER_ID}/{LEDGER_ENTRY_ID}
```

