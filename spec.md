# Open Service Broker API (master - might contain changes that are not yet released)

## Table of Contents
  - [API Overview](#api-overview)
  - [Notations and Terminology](#notations-and-terminology)
  - [Changes](#changes)
    - [Change Policy](#change-policy-for-minor-versions)
    - [Changes Since v2.15](#changes-since-v215)
  - [Headers](#headers)
    - [API Version Header](#api-version-header)
    - [Originating Identity](#originating-identity)
    - [Request Identity](#request-identity)
  - [Platform to Service Broker Authentication](#platform-to-service-broker-authentication)
  - [URL Properties](#url-properties)
  - [Service Broker Errors](#service-broker-errors)
  - [Content Type](#content-type)
  - [Catalog Management](#catalog-management)
  - [Synchronous and Asynchronous Operations](#synchronous-and-asynchronous-operations)
    - [Synchronous Operations](#synchronous-operations)
    - [Asynchronous Operations](#asynchronous-operations)
  - [Blocking Operations](#blocking-operations)
  - [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances)
  - [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings)
  - [Polling Interval and Duration](#polling-interval-and-duration)
  - [Provisioning](#provisioning)
  - [Fetching a Service Instance](#fetching-a-service-instance)
  - [Updating a Service Instance](#updating-a-service-instance)
  - [Binding](#binding)
    - [Binding Rotation](#binding-rotation)
    - [Types of Binding](#types-of-binding)
  - [Fetching a Service Binding](#fetching-a-service-binding)
  - [Unbinding](#unbinding)
  - [Deprovisioning](#deprovisioning)
  - [Orphan Mitigation](#orphan-mitigation)

## API Overview

The Open Service Broker API defines an HTTP(S) interface between Platforms and
Service Brokers.

The Service Broker is the component of the service that implements the Service
Broker API, for which a Platform is a client. Service Brokers are responsible
for advertising a catalog of Service Offerings and Service Plans to the
Platform, and acting on requests from the Platform for provisioning, binding,
unbinding, and deprovisioning.

In general, provisioning reserves a resource on a service; we call this
reserved resource a Service Instance. What a Service Instance represents can
vary by service. Examples include a single database on a multi-tenant server,
a dedicated cluster, or an account on a web application.

What a Service Binding represents MAY also vary by service. In general, creation
of a Service Binding either generates credentials necessary for accessing the
resource or provides the Service Instance with information for a configuration change.

A Platform MAY expose services from one or many Service Brokers, and an
individual Service Broker MAY support one or many Platforms using different URL
prefixes and credentials.

## Notations and Terminology

### Notational Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to
be interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

### Terminology

This specification defines the following terms:

- *Application*: Often the entity using a Service Instance will be a piece of
  software, however, this does not need to be the case. For the purposes of
  this specification, the term "Application" will be used to represent all
  entities that might make use of, and be bound to, a Service Instance.

- *Platform*: The software that will manage the cloud environment into which
  Applications are provisioned and Service Brokers are registered. Users will
  not directly provision Services from Service Brokers, rather they will ask
  the Platform to manage Services and interact with the Service Brokers for
  them.

- *Service*: A managed software offering that can be used by an Application.
  Typically, Services will expose some API that can be invoked to perform
  some action. However, there can also be non-interactive Services that can
  perform the desired actions without direct prompting from the Application.

- *Service Broker*: Service Brokers manage the lifecycle of Services. Platforms
  interact with Service Brokers to provision, and manage, Service Instances
  and Service Bindings.

- *Service Offering*: The advertisement of a Service that a Service Broker
  supports.

- *Service Plan*: The representation of the costs and benefits for a given
  variant of the Service Offering, potentially as a tier.

- *Service Instance*: An instantiation of a Service Offering and Service Plan.

- *Service Binding*: Represents the request to use a Service Instance. As part
  of this request there might be a reference to the entity, also known as the
  Application, that will use the Service Instance. Service Bindings will often
  contain the credentials that can then be used to communicate with the Service
  Instance.


## Changes

### Change Policy for Minor Versions

* Existing endpoints and fields MUST NOT be removed or renamed.
* New OPTIONAL endpoints, or new HTTP methods for existing endpoints, MAY be
added to enable support for new features.
* New fields MAY be added to existing request/response messages.
These fields MUST be OPTIONAL and SHOULD be ignored by clients and servers
that do not understand them.

### Changes Since v2.15

* Add guidance of how long the state of an operation SHOULD be remembered
* Add guidance to handle 500 errors from Service Instance update
* Add guidance to handle requests with invalid data
* Allow Service Brokers to indicate if a Service Instance is still usable after a failed update or deprovisioning and if an update can be repeated
* Specify that Platforms SHOULD NOT reuse IDs
* Allow Service Brokers to return additional information on GET requests
* Add CF and K8s annotations to the profile document
* Add support for ETag and If-Modified-Since headers
* Clarify the response code when Platform does not provide the REQUIRED API version header
* Service Instances can be labelled with information defined by the Service Broker

For changes in older versions, see the [release notes](https://github.com/openservicebrokerapi/servicebroker/blob/master/release-notes.md).

## Headers
The following HTTP Headers are defined for the operations detailed in this spec:

| Header | Type | Description |
| --- | --- | --- |
| X-Broker-API-Version* | string | See [API Version Header](#api-version-header). |
| X-Broker-API-Originating-Identity | string | See [Originating Identity](#originating-identity). |
| X-Broker-API-Request-Identity | string | See [Request Identity](#request-identity). |

\* Headers with an asterisk are REQUIRED.

### API Version Header

Requests from the Platform to the Service Broker MUST contain a header that
declares the version number of the Open Service Broker API that the Platform
is using:

`X-Broker-API-Version: 2.16`

The version numbers are in the format `MAJOR.MINOR` using semantic versioning.

This header allows Service Brokers to reject requests from Platforms for
versions they do not support. While minor API revisions will always be
additive, it is possible that Service Brokers depend on a feature from a newer
version of the API that is supported by the Platform. In this scenario the
Service Broker MAY reject the request with `412 Precondition Failed` and
provide a message that informs the operator of the API version that is to be
used instead.

If the request from the Platform to the Service Broker doesn't contain this
header, then the Service Broker MAY reject the request with `400 Bad Request`
and provide a message that the header is required.

### Originating Identity

Often a Service Broker will need to know the identity of the user that
initiated the request from the Platform. For example, this might be needed for
auditing or authorization purposes. In order to facilitate this, the Platform
will need to provide this identification information to the Service Broker on
each request. Platforms MAY support this feature, and if they do, they MUST
adhere to the following:
- For any OSBAPI request that is the result of an action taken by a Platform's
  user, there MUST be an associated `X-Broker-API-Originating-Identity` header on
  that HTTP request.
- Any OSBAPI request that is not associated with an action from a Platform's
  user, such as the Platform refetching the catalog, MAY exclude the header from
  that HTTP request.
- If present on a request, the `X-Broker-API-Originating-Identity` header
  MUST contain the identify information for the Platform's user that took
  the action to cause the request to be sent.

If the Platform chooses to group multiple end-user operations into one request
to the Broker, then the identity information associated with that one request
MUST accurately reflect the desired identity associated for each individual
change.

The format of the header MUST be:

```
X-Broker-API-Originating-Identity: Platform value
```

`Platform` MUST be a non-empty string indicating the Platform from which
the request is being sent. The specific value SHOULD match the values
defined in the [profile](profile.md) document for the `context.platform`
property. When `context` is sent as part of a message, this value MUST
be the same as the `context.platform` value.

`value` MUST be a Base64 encoded string. The string MUST be a serialized
JSON object. The specific properties will be Platform specific - see
the [profile](profile.md) document for more information.

For example:
```
X-Broker-API-Originating-Identity: cloudfoundry eyANCiAgInVzZXJfaWQiOiAiNjgzZWE3NDgtMzA5Mi00ZmY0LWI2NTYtMzljYWNjNGQ1MzYwIg0KfQ==
```

Where the `value`, when decoded, is:
```
{
  "user_id": "683ea748-3092-4ff4-b656-39cacc4d5360"
}
```

Note that not all messages sent to a Service Broker are initiated by an
end-user of the Platform. For example, during
[Orphan Mitigation](#orphan-mitigation) or during the querying of the Service
Broker's catalog, the Platform might not have an end-user with which to
associate the request, therefore in those cases the originating identity header
would not be included in those messages.

### Request Identity

A Platform might wish to uniquely identify a specific request as it flows throughout the system.
For example, this might be used for logging for request tracing purposes. In order to facilitate
this, Platforms will need to provide identification information to the Service Broker for each
request. Platforms MAY support this feature, and if they do, they MUST adhere to the following:
- For any OSBAPI request, there MUST be an associated `X-Broker-API-Request-Identity` header on
  the HTTP request.
- The Service Broker MAY include this value in log messages generated as a result of the request.
- The Service Broker SHOULD include this header in the response to the request.
The format of the header MUST be:

```
X-Broker-API-Request-Identity: value
```

`value` MUST be a non-empty string indicating the identity of the
request being sent. The specific value MAY be unique for each request
sent to the broker. Using a GUID is RECOMMENDED.

## Vendor Extension Fields

Senders of messages defined by this specification MAY include additional
fields within the JSON objects. When adding new fields, unique prefixes
SHOULD be used for the field names to reduce the chances of conflicts with
future specification defined fields or other extensions.

Receivers of messages defined by this specification that contain unknown
extension fields MUST ignore those fields and MUST NOT halt processing
of those messages due to the presence of those fields. Receivers are under
no obligation to understand or process unknown extension fields.

## Platform to Service Broker Authentication

While the communication between a Platform and Service Broker MAY be unsecure,
it is RECOMMENDED that all communications between a Platform and a Service
Broker are secured via TLS and authenticated. If communications are secured
via TLS, the Platform and Service Broker SHOULD agree whether the Service
Broker will use a root-signed certificate or a self-signed certificate.

Unless there is some out of band communication and agreement between a
Platform and a Service Broker, the Platform MUST authenticate with the
Service Broker using HTTP basic authentication (the `Authorization:` header)
on every request. This specification does not specify how Platform and Service
Brokers agree on other methods of authentication.

Platforms and Service Brokers MAY agree on an authentication mechanism other
than basic authentication, but the specific agreements are not covered by this
specification. Please see the
[Platform Features authentication mechanisms wiki document](https://github.com/openservicebrokerapi/servicebroker/wiki/Platform-Features)
for details on these mechanisms.

If authentication is used, the Service Broker MUST authenticate the request
using the predetermined authentication mechanism, and MUST return a `401 Unauthorized`
response if the authentication fails.

Note: Using an authentication mechanism that is agreed to via out of band
communications could lead to interoperability issues with other Platforms.

## URL Properties

This specification defines the following properties that might appear within
URLs:
- `service_id`
- `plan_id`
- `instance_id`
- `binding_id`
- `operation`

While this specification places no restriction on the set of characters used
within these strings, it is RECOMMENDED that these properties only contain
characters from the "Unreserved Characters" as defined by
[RFC3986](https://tools.ietf.org/html/rfc3986#section-2.3). In other words:
uppercase and lowercase letters, decimal digits, hyphen, period, underscore
and tilde.

If a character outside of the "Unreserved Characters" set is used, then it
SHOULD be percent-encoded prior to being used as part of the HTTP request, per
[RFC3986](https://tools.ietf.org/html/rfc3986#section-2.1).

## Service Broker Errors

When a request to a Service Broker fails, the Service Broker MUST return an
appropriate HTTP response code. Where the specification defines the expected
response code, that response code MUST be used.

For error responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| error | string | A single word in camel case that uniquely identifies the error condition. If present, MUST be a non-empty string. |
| description | string | A user-facing error message explaining why the request failed. If present, MUST be a non-empty string. |
| instance_usable | boolean | If an update or deprovisioning operation failed, this flag indicates whether or not the Service Instance is still usable. If `true`, the Service Instance can still be used, `false` otherwise. This field MUST NOT be present for errors of other operations. Defaults to `true`. |
| update_repeatable | boolean | If an update operation failed, this flag indicates whether this update can be repeated or not. If `true`, the same update operation MAY be repeated and MAY succeed; if `false`, repeating the same update operation will fail again. This field MUST NOT be present for errors of other operations. Defaults to `true`. |

### Error Codes

There are failure scenarios described throughout this specification for which
the `error` field MUST contain a specific string. Service Broker authors MUST
use these error codes for the specified failure scenarios.

| Error | Reason | Expected Action |
| --- | --- | --- |
| AsyncRequired | This request requires client support for asynchronous service operations. | The query parameter `accepts_incomplete=true` MUST be included the request. |
| ConcurrencyError | The Service Broker does not support concurrent requests that mutate the same resource. | Clients MUST wait until pending requests have completed for the specified resources. |
| RequiresApp | The request body is missing the `app_guid` field. | The `app_guid` MUST be included in the request body. |
| MaintenanceInfoConflict | The `maintenance_info.version` field provided in the request does not match the `maintenance_info.version` field provided in the Service Broker's [Catalog](#catalog-management). | The Platform SHOULD fetch the latest version of the Service Broker's [Catalog](#catalog-management). |

Unless otherwise specified, an HTTP status code in the 4xx range MUST result in
the Service Broker's resources being semantically unchanged as a result of
the incoming request message. Additionally, an HTTP status code in the 5xx
range SHOULD result in the Service Broker's resources being semantically
unchanged as a result of the incoming request message. Note, the 5xx error
case is a "SHOULD" instead of a "MUST" because it might not be possible for
a Service Broker to guarantee that it can revert all possible effects of a
failed attempt at the requested operation.

## Content Type

All requests and responses defined in this specification with accompanying
bodies SHOULD contain a `Content-Type` header set to `application/json`.
If the `Content-Type` is not set, Service Brokers and Platforms MAY still
attempt to process the body. If a Service Broker rejects a request due
to a mismatched `Content-Type` or the body is unprocessable it SHOULD
respond with `400 Bad Request`.

## Catalog Management

The first endpoint that a Platform will interact with on the Service Broker is
the service catalog (`/v2/catalog`). This endpoint returns a list of all
services available on the Service Broker. Platforms query this endpoint from
all Service Brokers in order to present an aggregated user-facing catalog.

Periodically, a Platform MAY re-query the service catalog endpoint for a
Service Broker to see if there are any changes to the list of services.
Service Brokers MAY add, remove or modify (metadata, Service Plans, etc.) the list of
services from previous queries.

When determining what, if anything, has changed on a Service Broker, the
Platform MUST use the `id` of the resources (Service Offerings or Service Plans) as the only
immutable property and MUST use that to locate the same resource as was
returned from a previous query. Likewise, a Service Broker MUST NOT change the
`id` of a resource across queries, otherwise a Platform will treat it as a
different resource.

When a Platform receives different `id` values for the same type of resource,
even if all of the other metadata in those resources are the exact same, it
MUST treat them as separate instances of that resource.

Service Broker authors are expected to be cautious when removing Service Offerings and
Service Plans from their catalogs, as Platforms might have provisioned Service
Instances of these Service Plans. For example, Platforms might restrict the actions
that users can perform on existing Service Instances if the associated Service Offering
or Service Plan is deleted. Consider your deprecation strategy.

Platforms MAY have limits on the length of strings that they can handle or
display to end users, such as the description of a Service Offering or Service Plan. It
is RECOMMENDED that strings do not exceed 255 characters to increase the
likelihood of having compatibility with any Platform.

Service Brokers and Platforms MAY support the
[`ETag`](https://tools.ietf.org/html/rfc7232#section-2.3) and
[`If-Modified-Since`](https://tools.ietf.org/html/rfc7232#section-3.3)
HTTP headers to enable caching of the catalog.
(See [RFC 7232](https://tools.ietf.org/html/rfc7232) for details.)

The following sections describe catalog requests and responses in the Service
Broker API.

### Request

#### Route
`GET /v2/catalog`

#### cURL
```
$ curl http://username:password@service-broker-url/v2/catalog -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned upon successful processing of this request. The expected response body is below. |

#### Body

CLI clients will typically have restrictions on how names, such as Service Offering
and Service Plan names, will be provided by users. Therefore, this specification
defines a "CLI-friendly" string as a short string that MUST only use
alphanumeric characters, periods, and hyphens, with no spaces. This will make it
easier for users when they have to type it as an argument on the command line.
For comparison purposes, Service Offering and Service Plan names MUST be treated as
case-sensitive strings.

Note: In previous versions of the specification Service Offering and Service Plan names
were not allowed to use uppercase characters. However, this requirement was
not enforced and therefore to ensure backwards compatibility with existing
Service Brokers that might use uppercase characters the specification
has been changed.

For backwards compatibility reasons, this specification does not preclude
the use of CLI-unfriendly strings that might cause problems for command line
parsers (or that are not very meaningful to users), such as `-`.
It is therefore RECOMMENDED that implementations avoid such strings.

| Response Field | Type | Description |
| --- | --- | --- |
| services* | array of [Service Offering](#service-offering-object) objects | Schema of service objects defined below. MAY be empty. |

\* Fields with an asterisk are REQUIRED.

##### Service Offering Object

| Response Field | Type | Description |
| --- | --- | --- |
| name* | string | The name of the Service Offering. MUST be unique across all Service Offering objects returned in this response. MUST be a non-empty string. Using a CLI-friendly name is RECOMMENDED. |
| id* | string | An identifier used to correlate this Service Offering in future requests to the Service Broker. This MUST be globally unique such that Platforms (and their users) MUST be able to assume that seeing the same value (no matter what Service Broker uses it) will always refer to this Service Offering. MUST be a non-empty string. Using a GUID is RECOMMENDED. |
| description* | string | A short description of the service. MUST be a non-empty string. |
| tags | array of strings | Tags provide a flexible mechanism to expose a classification, attribute, or base technology of a service, enabling equivalent services to be swapped out without changes to dependent logic in applications, buildpacks, or other services. E.g. mysql, relational, redis, key-value, caching, messaging, amqp. |
| requires | array of strings | A list of permissions that the user would have to give the service, if they provision it. The only permissions currently supported are `syslog_drain`, `route_forwarding` and `volume_mount`. |
| bindable* | boolean | Specifies whether Service Instances of the service can be bound to applications. This specifies the default for all Service Plans of this Service Offering. Service Plans can override this field (see [Service Plan Object](#service-plan-object)). |
| instances_retrievable | boolean | Specifies whether the [Fetching a Service Instance](#fetching-a-service-instance) endpoint is supported for all Service Plans. |
| bindings_retrievable | boolean | Specifies whether the [Fetching a Service Binding](#fetching-a-service-binding) endpoint is supported for all Service Plans. |
| allow_context_updates | boolean | Specifies whether a Service Instance supports [Update](#updating-a-service-instance) requests when contextual data for the Service Instance in the Platform changes. |
| metadata | object | An opaque object of metadata for a Service Offering. It is expected that Platforms will treat this as a blob. Note that there are [conventions](profile.md#service-metadata) in existing Service Brokers and Platforms for fields that aid in the display of catalog data. |
| dashboard_client | [DashboardClient](profile.md#dashboard-client-object) | A Cloud Foundry extension described in [Catalog Extensions](profile.md#catalog-extensions). Contains the data necessary to activate the Dashboard SSO feature for this service. |
| plan_updateable | boolean | Whether the Service Offering supports upgrade/downgrade for Service Plans by default. Service Plans can override this field (see [Service Plan](#service-plan-object)). Please note that the misspelling of the attribute `plan_updatable` as `plan_updateable` was done by mistake. We have opted to keep that misspelling instead of fixing it and thus breaking backward compatibility. Defaults to false. |
| plans* | array of [Service Plan](#service-plan-object) objects | A list of Service Plans for this Service Offering, schema is defined below. MUST contain at least one Service Plan. |

\* Fields with an asterisk are REQUIRED.

Note: Platforms will typically use the Service Offering name as an input parameter
from their users to indicate which Service Offering they want to instantiate. Therefore,
it is important that these values be unique for all Service Offerings that have been
registered with a Platform. To achieve this goal service providers often will
prefix their Service Offering names with some unique value (such as the name of their
company). Additionally, some Platforms might modify the Service Offering names before
presenting them to their users. This specification places no requirements on
how Platforms might expose these values to their users.

##### Service Plan Object

| Response Field | Type | Description |
| --- | --- | --- |
| id* | string | An identifier used to correlate this Service Plan in future requests to the Service Broker. This MUST be globally unique such that Platforms (and their users) MUST be able to assume that seeing the same value (no matter what Service Broker uses it) will always refer to this Service Plan and for the same Service Offering. MUST be a non-empty string. Using a GUID is RECOMMENDED. |
| name* | string | The name of the Service Plan. MUST be unique within the Service Offering. MUST be a non-empty string. Using a CLI-friendly name is RECOMMENDED. |
| description* | string | A short description of the Service Plan. MUST be a non-empty string. |
| metadata | object | An opaque object of metadata for a Service Plan. It is expected that Platforms will treat this as a blob. Note that there are [conventions](profile.md#service-metadata) in existing Service Brokers and Platforms for fields that aid in the display of catalog data. |
| free | boolean | When false, Service Instances of this Service Plan have a cost. The default is true. |
| bindable | boolean | Specifies whether Service Instances of the Service Plan can be bound to applications. This field is OPTIONAL. If specified, this takes precedence over the `bindable` attribute of the Service Offering. If not specified, the default is derived from the Service Offering. |
| binding_rotatable | boolean | Whether a Service Binding of that Plan supports [Service Binding rotation](#binding-rotation). The default is false. |
| plan_updateable | boolean | Whether the Plan supports upgrade/downgrade/sidegrade to another version. This field is OPTIONAL. If specificed, this takes precedence over the Service Offering's `plan_updateable` field. If not specified, the default is derived from the Service Offering. Please note that the attribute is intentionally misspelled as `plan_updateable` for legacy reasons. |
| schemas | [Schemas](#schemas-object) | Schema definitions for Service Instances and Service Bindings for the Service Plan. |
| maximum_polling_duration | integer | A duration, in seconds, that the Platform SHOULD use as the Service's [maximum polling duration](#polling-interval-and-duration). |
| maintenance_info | [Maintenance Info](#maintenance-info-object) | Maintenance information for a Service Instance which is provisioned using the Service Plan. If provided, a version string MUST be provided and platforms MAY use this when [Provisioning](#provisioning) or [Updating](#updating-a-service-instance) a Service Instance. |

\* Fields with an asterisk are REQUIRED.

##### Schemas Object

| Response Field | Type | Description |
| --- | --- | --- |
| service_instance | [ServiceInstanceSchema](#service-instance-schema-object) | The schema definitions for creating and updating a Service Instance. |
| service_binding | [ServiceBindingSchema](#service-binding-schema-object) | The schema definition for creating a Service Binding. Used only if the Service Plan is bindable. |

##### Service Instance Schema Object

| Response Field | Type | Description |
| --- | --- | --- |
| create | [InputParametersSchema](#input-parameters-schema-object) | The schema definition for creating a Service Instance. |
| update | [InputParametersSchema](#input-parameters-schema-object) | The schema definition for updating a Service Instance. |

##### Service Binding Schema Object

| Response Field | Type | Description |
| --- | --- | --- |
| create | [InputParametersSchema](#input-parameters-schema-object) | The schema definition for creating a Service Binding. |

##### Input Parameters Schema Object

| Response Field | Type | Description |
| --- | --- | --- |
| parameters | JSON schema object | The schema definition for the input parameters. Each input parameter is expressed as a property within a JSON object. |

The following rules apply if `parameters` is included anywhere in the catalog:
* Platforms MUST support at least
[JSON Schema draft v4](http://json-schema.org/).
* Platforms SHOULD be prepared to support later versions of JSON schema.
* The `$schema` key MUST be present in the schema declaring the version of JSON
schema being used.
* Schemas MUST NOT contain any external references.
* Schemas MUST NOT be larger than 64kB.

##### Maintenance Info Object

| Response Field | Type | Description |
| --- | --- | --- |
| version* | string | This MUST be a string conforming to a [semantic version 2.0](https://semver.org/spec/v2.0.0.html). The Platform MAY use this field to determine whether a maintenance update is available for a Service Instance. |
| description | string | This SHOULD be a string describing the impact of the maintenance update, for example, important version changes, configuration changes, default value changes, etc. The Platform MAY present this information to the user before they trigger the maintenance update. |

\* Fields with an asterisk are REQUIRED.

```
{
  "services": [{
    "name": "fake-service",
    "id": "acb56d7c-XXXX-XXXX-XXXX-feb140a59a66",
    "description": "A fake service.",
    "tags": ["no-sql", "relational"],
    "requires": ["route_forwarding"],
    "bindable": true,
    "instances_retrievable": true,
    "bindings_retrievable": true,
    "allow_context_updates": true,
    "metadata": {
      "provider": {
        "name": "The name"
      },
      "listing": {
        "imageUrl": "http://example.com/cat.gif",
        "blurb": "Add a blurb here",
        "longDescription": "A long time ago, in a galaxy far far away..."
      },
      "displayName": "The Fake Service Broker"
    },
    "plan_updateable": true,
    "plans": [{
      "name": "fake-plan-1",
      "id": "d3031751-XXXX-XXXX-XXXX-a42377d3320e",
      "description": "Shared fake Server, 5tb persistent disk, 40 max concurrent connections.",
      "free": false,
      "metadata": {
        "max_storage_tb": 5,
        "costs":[
            {
               "amount":{
                  "usd":99.0
               },
               "unit":"MONTHLY"
            },
            {
               "amount":{
                  "usd":0.99
               },
               "unit":"1GB of messages over 20GB"
            }
         ],
        "bullets": [
          "Shared fake server",
          "5 TB storage",
          "40 concurrent connections"
        ]
      },
      "schemas": {
        "service_instance": {
          "create": {
            "parameters": {
              "$schema": "http://json-schema.org/draft-04/schema#",
              "type": "object",
              "properties": {
                "billing-account": {
                  "description": "Billing account number used to charge use of shared fake server.",
                  "type": "string"
                }
              }
            }
          },
          "update": {
            "parameters": {
              "$schema": "http://json-schema.org/draft-04/schema#",
              "type": "object",
              "properties": {
                "billing-account": {
                  "description": "Billing account number used to charge use of shared fake server.",
                  "type": "string"
                }
              }
            }
          }
        },
        "service_binding": {
          "create": {
            "parameters": {
              "$schema": "http://json-schema.org/draft-04/schema#",
              "type": "object",
              "properties": {
                "billing-account": {
                  "description": "Billing account number used to charge use of shared fake server.",
                  "type": "string"
                }
              }
            }
          }
        }
      },
      "maintenance_info": {
        "version": "2.1.1+abcdef",
        "description": "OS image update.\nExpect downtime."
      }
    }, {
      "name": "fake-plan-2",
      "id": "0f4008b5-XXXX-XXXX-XXXX-dace631cd648",
      "description": "Shared fake Server, 5tb persistent disk, 40 max concurrent connections. 100 async.",
      "free": false,
      "metadata": {
        "max_storage_tb": 5,
        "costs":[
            {
               "amount":{
                  "usd":199.0
               },
               "unit":"MONTHLY"
            },
            {
               "amount":{
                  "usd":0.99
               },
               "unit":"1GB of messages over 20GB"
            }
         ],
        "bullets": [
          "40 concurrent connections"
        ]
      }
    }]
  }]
}
```

## Synchronous and Asynchronous Operations

Platforms expect prompt responses to all API requests in order to provide
users with fast feedback. Service Broker authors SHOULD implement their
Service Brokers to respond promptly to all requests but will need to decide
whether to implement synchronous or asynchronous responses. Service Brokers
that can guarantee completion of the requested operation with the response
SHOULD return the synchronous response. Service Brokers that cannot guarantee
completion of the operation with the response SHOULD implement the
asynchronous response.

Providing a synchronous response for a provision, update, or bind operation
before actual completion causes confusion for users as their service might not
be usable and they have no way to find out when it will be. Asynchronous
responses set expectations for users that an operation is in progress and can
also provide updates on the status of the operation.

Support for synchronous or asynchronous responses MAY vary by Service
Offering, even by Service Plan.

### Synchronous Operations

To execute a request synchronously, the Service Broker need only return the
usual status codes: `201 Created` for provision and bind, and `200 OK` for
update, unbind, and deprovision. `200 OK` MAY be returned synchronously by
Service Brokers that accept provisioning requests with unchanged parameters
and synchronous operations.

Platforms that rely on eventual consistency are RECOMMENDED to use `409 Conflict`
as a no-op response and SHOULD use the `last_operation` endpoint to verify the status of
the provisioning request instead in asynchronous mode.

Service Brokers that support synchronous responses for provision, update, and
delete can ignore the `accepts_incomplete=true` query parameter if it is
provided by the client.

### Asynchronous Operations

For a Service Broker to return an asynchronous response, the query parameter
`accepts_incomplete=true` MUST be included the request. If the parameter is not
included or is set to `false`, and the Service Broker cannot fulfil the request
synchronously (guaranteeing that the operation is complete on response), then
the Service Broker MUST reject the request with the status code `422
Unprocessable Entity` and a response body containing error code
`"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The
error response MAY include a helpful error message in the `description` field
such as `"This Service Plan requires client support for asynchronous service
operations."`.

If the query parameter described above is present, and the Service Broker
executes the request asynchronously, the Service Broker MUST return the
asynchronous response `202 Accepted`.

An asynchronous response triggers the Platform to poll the Service Instance
or Service Binding's `last_operation` endpoint until the Service Broker
indicates that the requested operation has succeeded or failed. Service Brokers
MAY include a status message with each response for the `last_operation`
endpoint that provides visibility to end users as to the progress of the
operation.

## Blocking Operations

Service Brokers MAY choose the degree to which they support concurrent
requests, ranging from not supporting them at all to only supporting them
in selective situations. If a Service Broker receives a request that it is
not able to process due a concurrency issue then the Service Broker MUST
reject the request with a HTTP `422 Unprocessable Entity` and a response body
containing error code `"ConcurrencyError"` (see
[Service Broker Errors](#service-broker-errors)). The error response MAY include
a helpful error message in the `description` field such as `"Another operation
for this Service Instance is in progress."`.

Upon receiving this error response, Platforms MUST NOT perform
[Orphan Mitigation](#orphan-mitigation).

Brokers MAY choose to treat the creation of a Service Binding as a mutation of
the corresponding Service Instance - it is an implementation choice. Doing so
would cause Platforms to serialize multiple Service Binding creation requests
when they are directed at the same Service Instance if concurrent updates are
not supported.

## Polling Last Operation for Service Instances

When a Service Broker returns status code `202 Accepted` for
[Provision](#provisioning), [Update](#updating-a-service-instance), or
[Deprovision](#deprovisioning), the Platform will begin polling the
`/v2/service_instances/:instance_id/last_operation` endpoint to obtain the
state of the last requested operation.

Returning `"state": "succeeded"` or `"state": "failed"` will cause the Platform
to cease polling.

### Request

#### Route
`GET /v2/service_instances/:instance_id/last_operation`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

#### Parameters

| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id | string | If present, it MUST be the ID of the Service Offering being used. |
| plan_id | string | If present, it MUST be the ID of the Service Plan for the Service Instance. If this endpoint is being polled as a result of changing the Service Plan through a [Service Instance Update](#updating-a-service-instance), the ID of the Service Plan prior to the update MUST be used. |
| operation | string | A Service Broker-provided identifier for the operation. When a value for `operation` is included with asynchronous responses for [Provision](#provisioning), [Update](#updating-a-service-instance), and [Deprovision](#deprovisioning) requests, the Platform MUST provide the same value using this query parameter as a percent-encoded string. If present, MUST be a non-empty string. |

Note: Although the request query parameters `service_id` and `plan_id` are not
mandatory, the Platform SHOULD include them on all `last_operation` requests
it makes to Service Brokers.

#### cURL
```
$ curl http://username:password@service-broker-url/v2/service_instances/:instance_id/last_operation -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned upon successful processing of this request. The expected response body is below. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 404 Not Found | MUST be returned if the Service Instance being polled does not exist. |
| 410 Gone | Appropriate only for asynchronous delete operations. The Platform MUST consider this response a success and forget about the resource. Returning this while the Platform is polling for create or update operations SHOULD be interpreted as an invalid response and the Platform SHOULD continue polling. |

Responses with any other status code SHOULD be interpreted as an error or
invalid response. The Platform SHOULD continue polling until the Service Broker
returns a valid response or the
[maximum polling duration](#polling-interval-and-duration) is reached.

#### Body

For success responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| state* | string | Valid values are `in progress`, `succeeded`, and `failed`. While `"state": "in progress"`, the Platform SHOULD continue polling. A response with `"state": "succeeded"` or `"state": "failed"` MUST cause the Platform to cease polling. |
| description | string | A user-facing message that can be used to tell the user details about the status of the operation. If present, MUST be a non-empty string. |
| instance_usable | boolean | If an update or deprovisioning operation failed, this flag indicates whether or not the Service Instance is still usable. If `true`, the Service Instance can still be used, `false` otherwise. This field MUST NOT be present for errors of other operations. Defaults to `true`. |
| update_repeatable | boolean | If an update operation failed, this flag indicates whether this update can be repeated or not. If `true`, the same update operation MAY be repeated and MAY succeed; if `false`, repeating the same update operation will fail again. This field MUST NOT be present for errors of other operations. Defaults to `true`. |

The response MAY also include the `Retry-After` HTTP header. This header will
indicate how long the Platform SHOULD wait before polling again and is
intended to prevent unnecessary, and premature, calls to the `last_operation`
endpoint. It is RECOMMENDED that the header include a duration rather than a
timestamp.

\* Fields with an asterisk are REQUIRED.

```
{
  "state": "in progress",
  "description": "Creating service (10% complete)."
}
```

For asynchronous provision operations, if the response contains
`"state": "failed"` then the Platform might need to perform
[Orphan Mitigation](#orphan-mitigation).

Service Brokers SHOULD NOT forget the state of an operation immediately after
returning a `"succeeded"` or `"failed"` state in case the Platform needs to ask
again.

## Polling Last Operation for Service Bindings

When a broker returns status code `202 Accepted` for [Binding](#binding) or
[Unbinding](#unbinding), the Platform will begin polling the
`/v2/service_instances/:instance_id/service_bindings/:binding_id/last_operation`
endpoint to obtain the state of the last requested operation.

Returning `"state": "succeeded"` or `"state": "failed"` will cause the Platform
to cease polling and, in the case of a [Binding](#binding) request, information
regarding the Service Binding can then immediately be fetched using the
[Fetching a Service Binding](#fetching-a-service-binding) endpoint.

### Request

#### Route
`GET /v2/service_instances/:instance_id/service_bindings/:binding_id/last_operation`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

`:binding_id` MUST be the ID of a previously provisioned Service Binding for that
instance.

#### Parameters

The request provides these query string parameters as useful hints for brokers.

| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id | string | ID of the Service Offering from the catalog. If present, MUST be a non-empty string. |
| plan_id | string | ID of the Service Plan from the catalog. If present, MUST be a non-empty string. |
| operation | string | A broker-provided identifier for the operation. When a value for `operation` is included with asynchronous responses for [Binding](#binding) and [Unbinding](#unbinding) requests, the Platform MUST provide the same value using this query parameter as a URL-encoded string. If brokers do not return this `operation` field, only one asynchronous operation MAY be supported at a time. If present, MUST be a non-empty string. |

Note: Although the request query parameters `service_id` and `plan_id` are not
mandatory, the Platform SHOULD include them on all `last_operation` requests it
makes to Service Brokers.

#### cURL
```
$ curl http://username:password@broker-url/v2/service_instances/:instance_id/service_bindings/:binding_id/last_operation
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned upon successful processing of this request. The expected response body is below. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 404 Not Found | MUST be returned if the Service Binding being polled does not exist. |
| 410 Gone | Appropriate only for asynchronous delete operations. The Platform MUST consider this response a success and remove the resource from its database. Returning this while the Platform is polling for create operations SHOULD be interpreted as an invalid response and the Platform SHOULD continue polling. |

Responses with any other status code SHOULD be interpreted as an error or
invalid response. The Platform SHOULD continue polling until the broker returns
a valid response or the
[maximum polling duration](#polling-interval-and-duration) is reached.

#### Body

For success responses, the following fields are defined:

| Response field | Type | Description |
| --- | --- | --- |
| state* | string | Valid values are `in progress`, `succeeded`, and `failed`. While `"state": "in progress"`, the Platform SHOULD continue polling. A response with `"state": "succeeded"` or `"state": "failed"` MUST cause the Platform to cease polling. |
| description | string | A user-facing message that can be used to tell the user details about the status of the operation. |

The response MAY also include the `Retry-After` HTTP header. This header will
indicate how long the Platform SHOULD wait before polling again and is
intended to prevent unnecessary, and premature, calls to the `last_operation`
endpoint. It is RECOMMENDED that the header include a duration rather than a
timestamp.

\* Fields with an asterisk are REQUIRED.

```
{
  "state": "in progress",
  "description": "Creating binding (10% complete)."
}
```

If the response contains `"state": "failed"`, then the Platform might need to
perform [Orphan Mitigation](#orphan-mitigation).

Service Brokers SHOULD NOT forget the state of an operation immediately after
returning a `"succeeded"` or `"failed"` state in case the Platform needs to ask
again.

## Polling Interval and Duration

The frequency and maximum duration of polling MAY vary by Platform.
Additionally, Service Brokers can specify the maximum time a Platform SHOULD
poll via the `maximum_polling_duration` field returned by the
[Service Plan Object](#service-plan-object). If either the Platform or Service
Plan's maximum polling duration is reached, the Platform SHOULD cease polling
and the operation state MUST be considered `failed`.

## Provisioning

When the Service Broker receives a provision request from the Platform, it
MUST take whatever action is necessary to create a new resource. What
provisioning represents varies by Service Offering and Service Plan, although there are several
common use cases. For a MySQL service, provisioning could result in an empty
dedicated database server running on its own VM or an empty schema on a shared
database server. For non-data services, provisioning could just mean an
account on an multi-tenant SaaS application.

### Request

#### Route
`PUT /v2/service_instances/:instance_id`

`:instance_id` MUST be a globally unique non-empty string.
This ID will be used for future requests (bind and deprovision), so the
Service Broker will use it to correlate the resource it creates.

Platforms SHOULD NOT reuse IDs, since Service Brokers MAY NOT support this.

#### Parameters
| Parameter Name | Type | Description |
| --- | --- | --- |
| accepts_incomplete | boolean | A value of true indicates that the Platform and its clients support asynchronous Service Broker operations. If this parameter is not included in the request, and the Service Broker can only provision a Service Instance of the requested Service Plan asynchronously, the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

#### Body
| Request Field | Type | Description |
| --- | --- | --- |
| service_id* | string | MUST be the ID of a Service Offering from the catalog for this Service Broker. |
| plan_id* | string | MUST be the ID of a Service Plan from the Service Offering that has been requested. |
| context | object | Contextual data for the Service Instance. `context` will replace `organization_guid` and `space_guid` in future versions of the specification - in the interim both SHOULD be used to ensure interoperability with old and new implementations. |
| organization_guid* | string | Deprecated in favor of `context`. The Platform GUID for the organization under which the Service Instance is to be provisioned. Although most Service Brokers will not use this field, it might be helpful for executing operations on a user's behalf. MUST be a non-empty string. |
| space_guid* | string | Deprecated in favor of `context`. The identifier for the project space within the Platform organization. Although most Service Brokers will not use this field, it might be helpful for executing operations on a user's behalf. MUST be a non-empty string. |
| parameters | object | Configuration parameters for the Service Instance. Service Brokers SHOULD ensure that the client has provided valid configuration parameters and values for the operation. |
| maintenance_info | [Maintenance Info](#maintenance-info-object) | If a Service Broker provides maintenance information for a Service Plan in its [Catalog](#catalog-management), a Platform MAY provide the same maintenance information when provisioning a Service Instance. Any field except for `maintenance_info.version` will be ignored. This field can be used to ensure that the end-user of a Platform is provisioning what they are expecting since maintenance information can be used to describe important information (such as the version of the operating system the Service Instance will run on). If a Service Broker's catalog has changed and new maintenance information version is available for the Service Plan being provisioned, then the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

\* Fields with an asterisk are REQUIRED.

```
{
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "organization_guid": "org-guid-here",
  "space_guid": "space-guid-here",
  "parameters": {
    "parameter1": 1,
    "parameter2": "foo"
  },
  "maintenance_info": {
    "version": "2.1.1+abcdef",
  }
}
```

#### cURL
```
$ curl http://username:password@service-broker-url/v2/service_instances/:instance_id?accepts_incomplete=true -d '{
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "organization_guid": "org-guid-here",
  "space_guid": "space-guid-here",
  "parameters": {
    "parameter1": 1,
    "parameter2": "foo"
  }
}' -X PUT -H "X-Broker-API-Version: 2.16" -H "Content-Type: application/json"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | SHOULD be returned if the Service Instance already exists, is fully provisioned, and the requested parameters are identical to the existing Service Instance. The expected response body is below. *This response is only valid in synchronous operations*. |
| 201 Created | MUST be returned if the Service Instance was provisioned as a result of this request. The expected response body is below. |
| 202 Accepted | MUST be returned if the Service Instance provisioning is in progress. The `operation` string MUST match that returned for the original request. This triggers the Platform to poll the [Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint for operation status. Note that a re-sent `PUT` request MUST return a `202 Accepted`, not a `200 OK`, if the Service Instance is not yet fully provisioned. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 409 Conflict | MUST be returned if a Service Instance with the same id already exists or is being provisioned but with different attributes. |
| 422 Unprocessable Entity | MUST be returned if the Service Broker only supports asynchronous provisioning for the requested Service Plan and the request did not include `?accepts_incomplete=true`. The response body MUST contain error code `"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service Plan requires client support for asynchronous service operations."`. This MUST also be returned if the `maintenance_info.version` provided in the request does not match the `maintenance_info.version` described for the Service Plan in the Service Broker's [catalog](#catalog-management). In this case, the response body MUST contain error code `"MaintenanceInfoConflict"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"The maintenance information for the requested Service Plan has changed."`. |

Responses with any other status code MUST be interpreted as a failure and the
Platform might need to perform [Orphan Mitigation](#orphan-mitigation).

#### Body

For success responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| dashboard_url | string | The URL of a web-based management user interface for the Service Instance; we refer to this as a service dashboard. The URL MUST contain enough information for the dashboard to identify the resource being accessed (`9189kdfsk0vfnku` in the example below). Note: a Service Broker that wishes to return `dashboard_url` for a Service Instance MUST return it with the initial response to the provision request, even if the service is provisioned asynchronously. If present, MUST be a string or null. |
| operation | string | For asynchronous responses, Service Brokers MAY return an identifier representing the operation. The value of this field MUST be provided by the Platform with requests to the [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint in a percent-encoded query parameter. If present, MAY be null, and MUST NOT contain more than 10,000 characters. |
| metadata | [ServiceInstanceMetadata](#service-instance-metadata) object | An OPTIONAL object containing metadata for the Service Instance. |
```
{
  "dashboard_url": "http://example-dashboard.example.com/9189kdfsk0vfnku",
  "operation": "task_10",
  "metadata": {
    "labels": {
      "key1" : "value1",
      "key2" : "value2"
    },
    attributes: {
      "broker.generated.attr1": "value1",
      "broker.generated.attr2": "value2"
    }
  }
}
```

## Fetching a Service Instance

If `"instances_retrievable" :true` is declared for a Service Offering in the
[Catalog](#catalog-management) endpoint, Service Brokers MUST support this
endpoint for all Service Plans of the Service Offering and this endpoint MUST be available
immediately after the
[Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances)
endpoint returns `"state": "succeeded"` for a [Provisioning](#provisioning)
operation. Otherwise, Platforms SHOULD NOT attempt to call this endpoint under
any circumstances.

By polling this endpoint, Platforms MAY refresh their view of a successfully provisioned Service Instance, and discover out-of-bands changes that were applied on a Service Instance (such as parameters, dashboard url or maintenance info).

### Request

##### Route
`GET /v2/service_instances/:instance_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

#### Parameters

The request provides these query string parameters as useful hints for brokers.

| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id | string | ID of the Service Offering from the catalog. If present, MUST be a non-empty string. |
| plan_id | string | ID of the Service Plan from the catalog. If present, MUST be a non-empty string. |

##### cURL
```
$ curl 'http://username:password@broker-url/v2/service_instances/:instance_id' -X GET -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | The expected response body is below. |
| 404 Not Found | MUST be returned if the Service Instance does not exist or if a provisioning operation is still in progress. |
| 422 Unprocessable Entity | MUST be returned if the Service Instance is being updated and therefore cannot be fetched at this time. The response body MUST contain error code `"ConcurrencyError"` (see [Service Broker Errors](#service-broker-errors)). |

Responses with any other status code MUST be interpreted as a failure and the
Platform MUST continue to remember the Service Instance.

##### Body

For success responses, the following fields are defined:

| Response field | Type | Description |
| --- | --- | --- |
| service_id | string | The ID of the Service Offering from the catalog that is associated with the Service Instance. |
| plan_id | string | The ID of the Service Plan from the catalog that is associated with the Service Instance. |
| dashboard_url | string | The URL of a web-based management user interface for the Service Instance; we refer to this as a service dashboard. The URL MUST contain enough information for the dashboard to identify the resource being accessed (`9189kdfsk0vfnku` in the example below). Note: a Service Broker that wishes to return `dashboard_url` for a Service Instance MUST return it with the initial response to the provision request, even if the service is provisioned asynchronously. |
| parameters | object | Configuration parameters for the Service Instance. |
| maintenance_info | [Maintenance Info](#maintenance-info-object) | If a Service Broker provides maintenance information for a Service Plan in its [Catalog](#catalog-management), a Broker MAY return the maintenance information currently associated with the Service Instance. Any field except for `maintenance_info.version` SHOULD be ignored by the Platform. This field MAY be used by the Platform to inform the end-user of unattended maintenances that were triggered out-of-band and applied to the Service Instance. |
| metadata | [ServiceInstanceMetadata](#service-instance-metadata) object | An OPTIONAL object containing metadata for the Service Instance. |

Service Brokers MAY choose to not return some or all parameters when a Service Instance is fetched - for example,
if it contains sensitive information.

```
{
  "dashboard_url": "http://example-dashboard.example.com/9189kdfsk0vfnku",
  "parameters": {
    "billing-account": "abcde12345"
  },
  "metadata": {
    "labels": {
      "key1" : "value1",
      "key2" : "value2"
    },
    attributes: {
      "broker.generated.attr1": "value1",
      "broker.generated.attr2": "value2"
    }
  }
}
```

## Updating a Service Instance

By implementing this endpoint, Service Broker authors can:
* Enable users to modify the Service Plan of a Service Instance. By changing the
  Service Plan, users can upgrade or downgrade their Service Instance to other
  plans.
* Enable users to modify the parameters of a Service Instance. By modifying
  parameters, users can change configuration options that are specific to a
  Service or Service Plan.
* Enable Platforms to send an update request for a Service Instance containing
  only contextual data (no changes to the Service Plan or parameters). This MAY
  be used by Platforms to let Service Brokers know when contextual information
  for a Service Instance has changed (i.e. `instance_name` in the
  [Cloud Foundry Context Object](profile.md#cloud-foundry-context-object). To
  enable support for Platforms to send an update request for a Service Instance
  containing only contextual data, a Service Broker MUST declare support by
  including `"allow_context_updates": true` in its
  [catalog endpoint](#catalog-management).
* Enable Platforms to update maintenance information (allowing users to perform
  maintenance on their Service Instance, such as upgrading the underlying operating
  system the Service Instance is running on).

To enable support for the update of the Service Plan, a Service Broker MUST declare
support per Service Offering by including `"plan_updateable": true` in either the
Service Offering or Service Plan in its [catalog endpoint](#catalog-management).

If `"plan_updateable": true` is declared for a Service Plan in the
[Catalog](#catalog-management) endpoint, the Platform MAY request a Service Plan
change on a Service Instance using the given Service Plan. Otherwise, Platforms
MUST NOT make any Service Plan change requests to the Service Broker for any
Service Instance using the given Service Plan, but MAY request an update to the
Service Instance parameters or perform maintenance on the Service Instance.

Not all permutations of Service Plan changes are expected to be supported. For
example, a service might support upgrading from Service Plan "shared small" to
"shared large" but not to Service Plan "dedicated". It is up to the Service
Broker to validate whether a particular permutation of Service Plan change is
supported. If a particular Service Plan change is not supported, the Service
Broker SHOULD return a meaningful error message in response.

### Request

#### Route
`PATCH /v2/service_instances/:instance_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

#### Parameters
| Parameter Name | Type | Description |
| --- | --- | --- |
| accepts_incomplete | boolean | A value of true indicates that the Platform and its clients support asynchronous Service Broker operations. If this parameter is not included in the request, and the Service Broker can only update a Service Instance of the requested Service Plan asynchronously, the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

#### Body

| Request Field | Type | Description |
| --- | --- | --- |
| context | object | Contextual data for the Service Instance. |
| service_id* | string | MUST be the ID of a Service Offering from the catalog for this Service Broker. |
| plan_id | string | If present, MUST be the ID of a Service Plan from the Service Offering that has been requested. If this field is not present in the request message, then the Service Broker MUST NOT change the Service Plan of the Service Instance as a result of this request. |
| parameters | object | Configuration parameters for the Service Instance. Service Brokers SHOULD ensure that the client has provided valid configuration parameters and values for the operation. See "Note" below. |
| previous_values | [PreviousValues](#previous-values-object) | Information about the Service Instance prior to the update. |
| maintenance_info | [Maintenance Info](#maintenance-info-object) | If a Service Broker provides maintenance information for a Service Plan in its [Catalog](#catalog-management), a Platform MAY provide the same maintenance information when updating a Service Instance. Any field except for `maintenance_info.version` will be ignored. This field can be used to perform maintenance on a Service Instance (for example, to upgrade the underlying operating system the Service Instance is running on). If a Service Broker's catalog has changed and new maintenance information version is available for the Service Plan that the Service Instance being updated is using, then the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

\* Fields with an asterisk are REQUIRED.

##### Previous Values Object

| Request Field | Type | Description |
| --- | --- | --- |
| service_id | string | Deprecated; determined to be unnecessary as the value is immutable. If present, it MUST be the ID of the Service Offering for the Service Instance. |
| plan_id | string | If present, it MUST be the ID of the Service Plan prior to the update. |
| organization_id | string | Deprecated as it was redundant information. The organization ID for the Service Instance MUST be provided by Platforms in the top-level field `context`. If present, it MUST be the ID of the organization specified for the Service Instance. |
| space_id | string | Deprecated as it was redundant information. The space ID for the Service Instance MUST be provided by Platforms in the top-level field `context`. If present, it MUST be the ID of the space specified for the Service Instance. |
| maintenance_info | [Maintenance Info](#maintenance-info-object) | The maintenance information that was used when the Service Instance was [provisioned](#provisioning) or when it was last [updated](#updating-a-service-instance). |

Note: The `parameters` specified are expected to be the values specified
by an end-user. Whether the user chooses to include the complete set of
configuration options or just a subset (or even none) is their choice. How a
Service Broker interprets these parameters (including the absence of any
particular parameter) is out of scope of this specification - with the
exception that if this field is not present in the request then the
Service Broker MUST NOT change the parameters of the instance as a result of
this request.

Since some Service Instances will provide a `dashboard_url`, it is possible
that a user has modified some of these parameters via the dashboard and
therefore the Platform might not be aware of these changes. For this reason,
Platforms SHOULD NOT include any parameters on the request that
the user did not explicitly specify in their request for the update.

\* Fields with an asterisk are REQUIRED.

```
{
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "parameters": {
    "parameter1": 1,
    "parameter2": "foo"
  },
  "previous_values": {
    "plan_id": "old-service-plan-id-here",
    "service_id": "service-offering-id-here",
    "organization_id": "org-guid-here",
    "space_id": "space-guid-here",
    "maintenance_info": {
      "version": "2.1.1+abcdef",
    }
  },
  "maintenance_info": {
    "version": "2.1.1+abcdef",
  }
}
```

#### cURL
```
$ curl http://username:password@service-broker-url/v2/service_instances/:instance_id?accepts_incomplete=true -d '{
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "parameters": {
    "parameter1": 1,
    "parameter2": "foo"
  },
  "previous_values": {
    "plan_id": "old-service-plan-id-here",
    "service_id": "service-offering-id-here",
    "organization_id": "org-guid-here",
    "space_id": "space-guid-here"
  }
}' -X PATCH -H "X-Broker-API-Version: 2.16" -H "Content-Type: application/json"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned if the request's changes have been applied or MAY be returned if the request's changes have had no effect. The expected response body is `{}`. |
| 202 Accepted | MUST be returned if the Service Instance update is in progress. The `operation` string MUST match that returned for the original request. This triggers the Platform to poll the [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint for operation status. Note that a re-sent `PATCH` request MUST return a `202 Accepted`, not a `200 OK`, if the requested update has not yet completed. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 422 Unprocessable entity | MUST be returned if the requested change is not supported or if the request cannot currently be fulfilled due to the state of the Service Instance (e.g. Service Instance utilization is over the quota of the requested Service Plan). Additionally, this MUST be returned if the Service Broker only supports asynchronous update for the requested Service Plan and the request did not include `?accepts_incomplete=true`; in this case the response body MUST contain a error code `"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service Plan requires client support for asynchronous service operations."`. Additionally, this MUST be returned if the `maintenance_info.version` provided in the request does not match the `maintenance_info.version` described for the Service Plan in the Service Broker's [catalog](#catalog-management). In this case, the response body MUST contain error code `"MaintenanceInfoConflict"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"The maintenance information for the requested Service Plan has changed."`. |

Responses with any other status code MUST be interpreted as a failure.
When the response includes a 4xx or 5xx status code, the Service Broker MUST
NOT apply any of the requested changes to the Service Instance.

When an update fails, the Service Instance can still be usable or unusable
or its state could be unknown to the Platform. If a Service Instance became
unusable, another update MAY repair the Service Instance.
The Platform SHOULD NOT allow the creation of new bindings of an unusable
Service Instance until the instance has been deleted or repaired by a
subsequent update.
If the broker does not indicate in the
[Error response](#service-broker-errors) or
[Last Operation response](#polling-last-operation-for-service-instances)
whether the Service Instance is usable or not, the Platform SHOULD assume
it is still usable.

A failed update might be repeatable. If the Service Broker
indicates in the [Error response](#service-broker-errors) or
[Last Operation response](#polling-last-operation-for-service-instances)
that retrying this update does not make sense, the Platform SHOULD NOT
repeat this update.
For example, if a certain plan change is not supported by the
Service Broker, all subsequent attempts will always fail, and the
Platform SHOULD NOT retry this.
Other updates MAY be possible.

#### Body

For success responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| dashboard_url | string | The updated URL of a web-based management user interface for the Service Instance; we refer to this as a service dashboard. The URL MUST contain enough information for the dashboard to identify the resource being accessed (`0129d920a083838` in the example below). Note: a Service Broker that wishes to return `dashboard_url` for a Service Instance MUST return it with the initial response to the update request, even if the Service Instance is being updated asynchronously. If not present or null, the Platform MUST retain the previous value of the `dashboard_url`. |
| operation | string | For asynchronous responses, Service Brokers MAY return an identifier representing the operation. The value of this field MUST be provided by the Platform with requests to the [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint in a percent-encoded query parameter. If present, MUST be a non-empty string. |
| metadata | [ServiceInstanceMetadata](#service-instance-metadata) object | An OPTIONAL object containing metadata for the Service Instance. |
```
{
  "dashboard_url": "http://example-dashboard.example.com/9189kdfsk0vfnku",
  "operation": "task_10",
  "metadata": {
    "labels": {
      "key1" : "value1",
      "key2" : "value2"
    },
    attributes: {
      "broker.generated.attr1": "value1",
      "broker.generated.attr2": "value2"
    }
  }
}
```

### Service Instance Metadata

| Response Field | Type | Description |
| --- | --- | --- |
| labels | object | Labels are broker specified key-value pairs specifying attributes of Service Instances that are meaningful and relevant to Platform users, but do not directly imply behaviour changes by the Platform. Platforms that support metadata labels MAY chose to update those, and if they do, they SHOULD replace all existing metadata labels with the labels received during provision or update. The Platform SHOULD ignore labels that do not adhere to the Platforms syntax. |
| attributes | object | Attributes are Broker specific key-value pairs generated by the Broker that MAY imply behavior changes by the Platform. Platforms that support attributes MAY chose to update attributes and the new value will be updated in the response body of the FETCH Service Instances. The Platform SHOULD ignore attributes that do not adhere to the Platform supported attribute list. |


## Binding

If `"bindable": true` is declared for a Service Offering or Service Plan in the
[Catalog](#catalog-management) endpoint, the Platform MAY request generation
of a Service Binding. Otherwise, Platforms MUST NOT make a binding request to
the Service Broker for any Service Instance using the given Service Offering
or Service Plan.

Note: Not all services need to be bindable --- some deliver value just from
being provisioned. Service Brokers that offer services that are bindable MUST
declare them as such using `"bindable": true` in the
[Catalog](#catalog-management). Service Brokers that do not offer any bindable
services do not need to implement the endpoint for bind requests.

Service Brokers MAY choose to only return the information that represents a
Service Binding once, either when the Service Binding is being created
synchronously, or when the Service Binding is first fetched via the [Fetching a
Service Binding](#fetching-a-service-binding) endpoint. However, in order for
the Platform to successfully use the Service Binding, the information MUST be
returned at least once.

In some cases, the creation of a Service Binding has to be accompanied by
additional network configuration. This could be the configuration of a firewall
or a load balancer or it could be the setup of a network tunnel or a VPN
connection.
To enable the Platform to do this in a service agnostic way, the Service Broker
SHOULD provide the endpoints that the Application uses to connect to the service
alongside the binding credentials.

### Binding Rotation

Some Service Bindings are not valid forever. Especially credentials expire and
have to be replaced at some point in time. The simplest form of exchanging a
binding is to create a new Service Binding, make it available to the
Application and remove and unbind the old one. In many cases, this requires a
restart of the Application.

But this approach has a few downsides. First of all, from the Service Broker
point of view, there is no continuity. The Service Broker doesn't know that
the new binding is the successor of the old one. If state is attached to the
old binding, the Service Broker is not able to transfer this state to the new
binding.
The second challenge is, that Platforms have to provide the binding parameters
again to the successor binding. But Platforms do not necessarily store these
parameter values. Without the values, a user has to provide them again and
that prevents an automated rotation of Service Bindings.

Therefore, this specification defines means to rotate Service Bindings.
A Service Broker can declare in the catalog per plan if it supports the
creation of a successor binding by setting the `binding_rotatable` field to
`true`. If the field is set to `false` or not present, the Platform MUST NOT
attempt to rotate a Service Binding of this plan.

To create a successor binding, the Platform MUST provide a
`predecessor_binding_id` field in the binding provisioning request. The value
of this field MUST be the Service Binding ID of a non-expired Service Binding
of the same Service Instance. The request creates a new Service Binding with a
new binding ID. Both Service Bindings, the new and the old one, MUST both be
valid in parallel until they expired or are deleted.

### Types of Binding

#### Credentials

Credentials are a set of information used by an Application or a user to
utilize the Service Instance. Credentials SHOULD be unique whenever possible, so
access can be revoked for each Service Binding without affecting consumers of other
Service Bindings for the Service Instance.

Service Brokers SHOULD also provide all network hosts and ports that the
Application uses to connect to the Service Instance via this Service Binding.
This data allows the Platform to adjust network configurations, if necessary.

#### Log Drain

There are a class of Service Offerings that provide aggregation, indexing, and
analysis of log data. To utilize these services an application that generates
logs needs information for the location to which it will stream logs. A create
binding response from a Service Broker that provides one of these services MUST
include a `syslog_drain_url`. The Platform MUST use the `syslog_drain_url` value
when sending logs to the service.

#### Route Services
Route services are a class of Service Offerings that intermediate requests to
applications, performing functions such as rate limiting or authorization. To
indicate support for route services, the catalog entry for the Service MUST
include the `"requires":["route_forwarding"]` property.

When creating a route service type of Service Binding, a Platform MUST send
a routable address, or endpoint, for the application along with the request to
create a Service Binding using `"bind_resource":{"route":"some-address.com"}`.
Service Brokers MAY support configuration specific to an address using
parameters; exposing this feature to users would require a Platform to support
binding multiple routable addresses to the same Service Instance.

If a service is deployed in a configuration to support this behavior, the
Service Broker MUST return a `route_service_url` in the response for a request
to create a Service Binding, so that the Platform knows where to proxy the application
request. If the service is deployed such that the network configuration to
proxy application requests through instances of the service is managed
out-of-band, the Service Broker MUST NOT return `route_service_url` in the
response.

#### Volume Services

There are a class of Service Offerings that provide network storage to applications
via volume mounts in the application container. A create Service Binding response from
one of these services MUST include `volume_mounts`.

### Request (Creating a Service Binding)

#### Route
`PUT /v2/service_instances/:instance_id/service_bindings/:binding_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

`:binding_id` MUST be a globally unique non-empty string.
This ID will be used for future unbind requests, so the Service Broker will use
it to correlate the resource it creates.

#### Parameters
| Parameter name | Type | Description |
| --- | --- | --- |
| accepts_incomplete | boolean | A value of true indicates that the Platform and its clients support asynchronous broker operations. If this parameter is not included in the request, and the broker can only perform a binding operation asynchronously, the broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

#### Body

| Request Field | Type | Description |
| --- | --- | --- |
| context | object | Contextual data for the Service Binding. |
| service_id* | string | MUST be the ID of the Service Offering that is being used. |
| plan_id* | string | MUST be the ID of the Servie Plan from the service that is being used. |
| app_guid | string | Deprecated in favor of `bind_resource.app_guid`. GUID of an application associated with the Service Binding to be created. If present, MUST be a non-empty string. |
| bind_resource | [BindResource](#bind-resource-object) | A JSON object that contains data for Platform resources associated with the Service Binding to be created. See [Bind Resource Object](#bind-resource-object) for more information. |
| parameters | object | Configuration parameters for the Service Binding. Service Brokers SHOULD ensure that the client has provided valid configuration parameters and values for the operation. |

\* Fields with an asterisk are REQUIRED.

##### Bind Resource Object

The `bind_resource` object contains Platform specific information related to
the context in which the service will be used. In some cases the Platform
might not be able to provide this information at the time of the binding
request, therefore the `bind_resource` and its fields are OPTIONAL.

Below are some common fields that MAY be used. Platforms MAY choose to add
additional ones as needed (see
[Bind Resource Object](profile.md#bind-resource-object) conventions).

| Request Field | Type | Description |
| --- | --- | --- |
| app_guid | string | GUID of an application associated with the Service Binding. For [credentials](#types-of-binding) bindings. MUST be unique within the scope of the Platform. |
| route | string | URL of the application to be intermediated. For [route services](#route-services) Service Bindings. |

`app_guid` represents the scope to which the Service Binding will apply within
the Platform. For example, in Cloud Foundry it might map to an "application"
while in Kubernetes it might map to a "namespace". The scope of what a
Platform maps the `app_guid` to is Platform specific and MAY vary across
binding requests.

```
{
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "bind_resource": {
    "app_guid": "app-guid-here"
  },
  "parameters": {
    "parameter1-name-here": 1,
    "parameter2-name-here": "parameter2-value-here"
  }
}
```


#### cURL
```
$ curl http://username:password@service-broker-url/v2/service_instances/:instance_id/service_bindings/:binding_id?accepts_incomplete=true -d '{
  "context": {
    "platform": "cloudfoundry",
    "some_field": "some-contextual-data"
  },
  "service_id": "service-offering-id-here",
  "plan_id": "service-plan-id-here",
  "bind_resource": {
    "app_guid": "app-guid-here"
  },
  "parameters": {
    "parameter1-name-here": 1,
    "parameter2-name-here": "parameter2-value-here"
  }
}' -X PUT -H "X-Broker-API-Version: 2.16" -H "Content-Type: application/json"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | SHOULD be returned if the Service Binding already exists and the requested parameters are identical to the existing Service Binding. The expected response body is below. *This response is only valid in synchronous operations*. |
| 201 Created | MUST be returned if the Service Binding was created as a result of this request. The expected response body is below. |
| 202 Accepted | MUST be returned if the binding is in progress. The `operation` string MUST match that returned for the original request. This triggers the Platform to poll the [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings) endpoint for operation status. Information regarding the Service Binding (i.e. credentials) MUST NOT be returned in this response. Note that a re-sent `PUT` request MUST return a `202 Accepted`, not a `200 OK`, if the Service Binding is not yet fully created. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 409 Conflict | MUST be returned if a Service Binding with the same id, for the same Service Instance, already exists or is being created but with different parameters. |
| 422 Unprocessable Entity | MUST be returned if the Service Broker requires that `app_guid` be included in the request body. The response body MUST contain error code `"RequiresApp"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service supports generation of credentials through binding an application only."`. Additionally, if the Service Broker rejects the request due to a concurrent request to create a Service Binding for the same Service Instance, then this error MUST be returned (see [Blocking Operations](#blocking-operations)). This MUST also be returned if the Service Broker only supports asynchronous bindings for the Service Instance and the request did not include `?accepts_incomplete=true`. In this case, the response body MUST contain error code `"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service Instance requires client support for asynchronous binding operations."`. |

Responses with any other status code MUST be interpreted as a failure and the
Platform might need to perform [Orphan Mitigation](#orphan-mitigation).

#### Body

For a `202 Accepted` response code, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| operation | string | For asynchronous responses, Service Brokers MAY return an identifier representing the operation. The value of this field MUST be provided by the Platform with requests to the [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings) endpoint in a URL encoded query parameter. If present, MUST be a string containing no more than 10,000 characters. |

For `200 OK` and `201 Created` response codes, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| metadata | [BindingMetadata](#binding-metadata-object) object | An OPTIONAL object containing metadata about this Service Binding. This metadata is mainly used to manage the Service Binding itself and SHOULD NOT contain any data that is needed to connect to the Service Instance. |
| credentials | object | A free-form hash of credentials that can be used by applications or users to access the service. MUST be returned if the Service Broker supports generation of credentials. |
| syslog_drain_url | string | A URL to which logs MUST be streamed. `"requires":["syslog_drain"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| route_service_url | string | A URL to which the Platform MUST proxy requests for the address sent with `bind_resource.route` in the request body. `"requires":["route_forwarding"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| volume_mounts | array of [VolumeMount](#volume-mount-object) objects | An array of configuration for remote storage devices to be mounted into an application container filesystem. `"requires":["volume_mount"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| endpoints | array of [Endpoint](#endpoint-object) objects | The network endpoints that the Application uses to connect to the Service Instance. If present, all Service Instance endpoints that are relevant for the Application MUST be in this list, even if endpoints are not reachable or host names are not resolvable from outside the service network. |

##### Binding Metadata Object

| Response Field | Type | Description |
| --- | --- | --- |
| expires_at | string | The date and time when the Service Binding becomes invalid and SHOULD NOT or CANNOT be used anymore. If present, the string MUST follow ISO 8601 and this pattern: `yyyy-mm-ddThh:mm:ss.sZ`. |
| renew_before | string | The date and time before the Service Binding SHOULD be renewed. Applications or Platforms MAY use this field to initiate a [Service Binding rotation](#binding-rotation) or create a new Service Binding on time. It is RECOMMENDED to trigger the creation of a new Service Binding shortly before this timestamp. If the `expires_at` field is also present, the `renew_before` timestamp MUST be before or equal to the `expires_at` timestamp. Service Brokers SHOULD leave enough time between both timestamps to create a new Service Binding including a buffer to enable continuity. If present, the string MUST follow ISO 8601 and this pattern: `yyyy-mm-ddThh:mm:ss.sZ`. |

##### Volume Mount Object

| Response Field | Type | Description |
| --- | --- | --- |
| driver* | string | Name of the volume driver plugin which manages the device. |
| container_dir* | string | The path in the application container onto which the volume will be mounted. This specification does not mandate what action the Platform is to take if the path specified already exists in the container. |
| mode* | string | "r" to mount the volume read-only or "rw" to mount it read-write. |
| device_type* | string | A string specifying the type of device to mount. Currently the only supported value is "shared". |
| device* | [Device](#device-object) | Device object containing device_type specific details. Currently only shared devices are supported. |

\* Fields with an asterisk are REQUIRED.

##### Device Object

Currently only shared devices are supported; a distributed file system which
can be mounted on all app instances simultaneously.

| Response Field | Type | Description |
| --- | --- | --- |
| volume_id* | string | ID of the shared volume to mount on every app instance. |
| mount_config | object | Configuration object to be passed to the driver when the volume is mounted. |

\* Fields with an asterisk are REQUIRED.

##### Endpoint Object

| Response Field | Type | Description |
| --- | --- | --- |
| host* | string | A host name or a single IP address. |
| ports* | array of strings | A non-empty array. Each element is either a single port (for example "443") or a port range (for example "9000-9010"). |
| protocol | string | The protocol. Valid values are `tcp`, `udp`, or `all`. The default value is `tcp`. |

\* Fields with an asterisk are REQUIRED.

```
{
  "credentials": {
    "uri": "mysql://mysqluser:pass@mysqlhost:3306/dbname",
    "username": "mysqluser",
    "password": "pass",
    "host": "mysqlhost",
    "port": 3306,
    "database": "dbname"
  },
  "endpoints": [
    {
      "host": "mysqlhost",
      "ports:" ["3306"]
    }
  ]
}
```

```
{
  "volume_mounts": [{
    "driver": "cephdriver",
    "container_dir": "/data/images",
    "mode": "r",
    "device_type": "shared",
    "device": {
      "volume_id": "bc2c1eab-05b9-482d-b0cf-750ee07de311",
      "mount_config": {
        "key": "value"
      }
    }
  }]
}
```

### Request (Rotating a Service Binding)

#### Route
`PUT /v2/service_instances/:instance_id/service_bindings/:binding_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

`:binding_id` MUST be a globally unique non-empty string.
This ID will be used for future unbind requests, so the Service Broker will use
it to correlate the resource it creates.

#### Parameters
| Parameter name | Type | Description |
| --- | --- | --- |
| accepts_incomplete | boolean | A value of true indicates that the Platform and its clients support asynchronous broker operations. If this parameter is not included in the request, and the broker can only perform a binding operation asynchronously, the broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

#### Body

| Request Field | Type | Description |
| --- | --- | --- |
| predecessor_binding_id* | string | MUST be the ID of non-expired Service Binding of the same Service Instance. |

\* Fields with an asterisk are REQUIRED.

### Response

The same response as in the response section above is expected.


## Fetching a Service Binding

If `"bindings_retrievable" :true` is declared for a Service Offering in the
[Catalog](#catalog-management) endpoint, Service Brokers MUST support this
endpoint for all Service Offerings and Service Plans that support bindings (`"bindable": true`)
and this endpoint MUST be available immediately after the
[Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings)
endpoint returns `"state": "succeeded"` for a [Binding](#binding) operation.

### Request

##### Route
`GET /v2/service_instances/:instance_id/service_bindings/:binding_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

`:binding_id` MUST be the ID of a previously provisioned Service Binding for that
instance.

#### Parameters

The request provides these query string parameters as useful hints for brokers.

| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id | string | ID of the Service Offering from the catalog. If present, MUST be a non-empty string. |
| plan_id | string | ID of the Service Plan from the catalog. If present, MUST be a non-empty string. |

##### cURL
```
$ curl 'http://username:password@broker-url/v2/service_instances/:instance_id/service_bindings/:binding_id' -X GET -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | The expected response body is below. |
| 404 Not Found | MUST be returned if the Service Binding does not exist or if a binding operation is still in progress. |

Responses with any other status code MUST be interpreted as a failure and the
Platform MUST continue to remember the Service Binding.

##### Body

For success responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| metadata | [BindingMetadata](#binding-metadata-object) object | An OPTIONAL object containing metadata about this Service Binding. This metadata is mainly used to manage the Service Binding itself and SHOULD NOT contain any data that is needed to connect to the Service Instance. |
| credentials | object | A free-form hash of credentials that can be used by applications or users to access the service. MUST be returned if the Service Broker supports generation of credentials and the Service Binding was provisioned asynchronously. |
| syslog_drain_url | string | A URL to which logs MUST be streamed. `"requires":["syslog_drain"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| route_service_url | string | A URL to which the Platform MUST proxy requests for the address sent with `bind_resource.route` in the request body. `"requires":["route_forwarding"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| volume_mounts | array of [VolumeMount](#volume-mount-object) objects | An array of configuration for mounting volumes. `"requires":["volume_mount"]` MUST be declared in the [Catalog](#catalog-management) endpoint or the Platform can consider the response invalid. |
| parameters | object | Configuration parameters for the Service Binding. |
| endpoints | array of [Endpoint](#endpoint-object) objects | The network endpoints that the Application uses to connect to the Service Instance. If present, all Service Instance endpoints that are relevant for the Application MUST be in this list, even if endpoints are not reachable or host names are not resolvable from outside the service network. |

Service Brokers MAY choose to not return some or all parameters when a Service Binding is fetched - for example,
if it contains sensitive information.

```
{
  "metadata": {
    "expires_at": "2019-12-31T23:59:59.0Z"
  },
  "credentials": {
    "uri": "mysql://mysqluser:pass@mysqlhost:3306/dbname",
    "username": "mysqluser",
    "password": "pass",
    "host": "mysqlhost",
    "port": 3306,
    "database": "dbname"
  },
  "endpoints": [
    {
      "host": "mysqlhost",
      "ports:" ["3306"]
    }
  ],
  "parameters": {
    "billing-account": "abcde12345"
  }
}
```

## Unbinding

Note: Service Brokers that do not provide any bindable Service Offerings or Service Plans do
not need to implement this endpoint.

When a Service Broker receives an unbind request from a Platform, it MUST
delete any resources associated with the Service Binding. In the case where
credentials were generated, this might result in requests to the Service
Instance failing to authenticate.

If a Service Broker accepts the request to delete a Service Binding during
the process of it being created, then it MUST have the net effect of halting
the current creation process and beginning the deletion of any resources
associated with the Service Binding. If the request to delete the Service Binding
is being performed asynchronously, then the
[Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings)
endpoint SHOULD indicate the state of the delete request (unless a different
`operation` identifier was provided by the Service Broker). If the request to
delete the Service Binding is being performed synchronously, then the
[Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings)
endpoint SHOULD indicate that the create request has a `state` value of `failed`.

### Request

#### Route

`DELETE /v2/service_instances/:instance_id/service_bindings/:binding_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

`:binding_id` MUST be the the ID of a previously provisioned Service Binding for that
Service Instance.

#### Parameters

| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id* | string | MUST be the ID of the Service Offering associated with the Service Binding being deleted. |
| plan_id* | string | MUST be the ID of the Service Plan associated with the Service Binding being deleted. |
| accepts_incomplete | boolean | A value of true indicates that the Platform and its clients support asynchronous Service Broker operations. If this parameter is not included in the request, and the Service Broker can only perform an unbinding operation asynchronously, the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

\* Query parameters with an asterisk are REQUIRED.

#### cURL

```
$ curl 'http://username:password@service-broker-url/v2/service_instances/:instance_id/
  service_bindings/:binding_id?service_id=service-offering-id-here&plan_id=service-plan-id-here&accepts_incomplete=true' -X DELETE -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned if the Service Binding was deleted as a result of this request. The expected response body is `{}`. |
| 202 Accepted | MUST be returned if the unbinding is in progress. The `operation` string MUST match that returned for the original request. This triggers the Platform to poll the [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings) endpoint for operation status. Note that a re-sent `DELETE` request MUST return a `202 Accepted`, not a `200 OK`, if the unbinding request has not completed yet. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 410 Gone | MUST be returned if the Service Binding does not exist. |
| 422 Unprocessable Entity | MUST also be returned if the Service Broker only supports asynchronous unbinding for the Service Instance and the request did not include `?accepts_incomplete=true`. The response body MUST contain error code `"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service Instance requires client support for asynchronous binding operations."`. Additionally, this MUST be returned if the Service Binding is being processed by some other operation and therefore cannot be deleted at this time. The response body MUST contain error code `"ConcurrencyError"` (see [Service Broker Errors](#service-broker-errors)). |

Responses with any other status code MUST be interpreted as a failure and the
Platform MUST continue to remember the Service Binding.

#### Body

For success responses, the following fields are defined:

| Response field | Type | Description |
| --- | --- | --- |
| operation | string | For asynchronous responses, Service Brokers MAY return an identifier representing the operation. The value of this field MUST be provided by the Platform with requests to the [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings) endpoint in a percent-encoded query parameter. If present, MUST be a string containing no more than 10,000 characters. |

\* Fields with an asterisk are REQUIRED.

```
{
  "operation": "task_10"
}
```

## Deprovisioning

When a Service Broker receives a deprovision request from a Platform, it MUST
delete any resources it created during the provision. Usually this means that
all resources are immediately reclaimed for future provisions.

Platforms MUST delete all Service Bindings for a Service Instance prior to attempting to
deprovision the Service Instance. This specification does not specify what a Service
Broker is to do if it receives a deprovision request while there are still
Service Bindings associated with it.

If a Service Broker accepts the request to delete a Service Instance during
the process of it being provisioned, then it MUST have the net effect of halting
the current creation process and beginning the deletion of any resources
associated with the Service Instance. If the request to deprovision the Service
Instance is being performed asynchronously, then the
[Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances)
endpoint SHOULD indicate the state of the deprovision request (unless a
different `operation` identifier was provided by the Service Broker). If the
request to deprovision the Service Instance is being performed synchronously, then the
[Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances)
endpoint SHOULD indicate that the provision request has a `state` value of
`failed`.

### Request

#### Route

`DELETE /v2/service_instances/:instance_id`

`:instance_id` MUST be the ID of a previously provisioned Service Instance.

#### Parameters

The request provides these query string parameters as useful hints for Service
Brokers.


| Query-String Field | Type | Description |
| --- | --- | --- |
| service_id* | string | MUST be the ID of the Service Offering associated with the Service Instance being deleted. |
| plan_id* | string | MUST be the ID of the Service Plan associated with the Service Instance being deleted. |
| accepts_incomplete | boolean | A value of true indicates that both the Platform and the requesting client support asynchronous deprovisioning. If this parameter is not included in the request, and the Service Broker can only deprovision a Service Instance of the requested Service Plan asynchronously, the Service Broker MUST reject the request with a `422 Unprocessable Entity` as described below. |

\* Query parameters with an asterisk are REQUIRED.

#### cURL
```
$ curl 'http://username:password@service-broker-url/v2/service_instances/:instance_id?accepts_incomplete=true
  &service_id=service-offering-id-here&plan_id=service-plan-id-here' -X DELETE -H "X-Broker-API-Version: 2.16"
```

### Response

| Status Code | Description |
| --- | --- |
| 200 OK | MUST be returned if the Service Instance was deleted as a result of this request. The expected response body is `{}`. |
| 202 Accepted | MUST be returned if the Service Instance deletion is in progress. The `operation` string MUST match that returned for the original request. This triggers the Platform to poll the [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint for operation status. Note that a re-sent `DELETE` request MUST return a `202 Accepted`, not a `200 OK`, if the delete request has not completed yet. |
| 400 Bad Request | MUST be returned if the request is malformed or missing mandatory data. MAY be returned if the request contains invalid data, in which case the error response MAY include a helpful error message in the `description` field (see [Service Broker Errors](#service-broker-errors)). |
| 410 Gone | MUST be returned if the Service Instance does not exist. |
| 422 Unprocessable Entity | MUST be returned if the Service Broker only supports asynchronous deprovisioning for the requested Service Plan and the request did not include `?accepts_incomplete=true`. The response body MUST contain error code `"AsyncRequired"` (see [Service Broker Errors](#service-broker-errors)). The error response MAY include a helpful error message in the `description` field such as `"This Service Plan requires client support for asynchronous service operations."`. Additionally, this MUST be returned if the Service Instance is being processed by some other operation and therefore cannot be deleted at this time. The response body MUST contain error code `"ConcurrencyError"` (see [Service Broker Errors](#service-broker-errors)). |

Responses with any other status code MUST be interpreted as a failure and the
Platform MUST remember the Service Instance.

When a deprovisioning fails, the Service Instance can still be usable or
unusable or its state could be unknown. If a Service Instance becomes unusable,
the Platform SHOULD NOT request new Service Bindings for that Service Instance.
If the broker does not indicate in the [Error response](#service-broker-errors)
or [Last Operation response](#polling-last-operation-for-service-instances)
whether the Service Instance is usable or not, the Platform SHOULD assume it is
still usable.

#### Body

For success responses, the following fields are defined:

| Response Field | Type | Description |
| --- | --- | --- |
| operation | string | For asynchronous responses, Service Brokers MAY return an identifier representing the operation. The value of this field MUST be provided by the Platform with requests to the [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) endpoint in a percent-encoded query parameter. If present, MUST NOT contain more than 10,000 characters. |

```
{
  "operation": "task_10"
}
```

## Orphan Mitigation

The Platform is the source of truth for Service Instances and Service Bindings.
Service Brokers are expected to have successfully provisioned all of the Service
Instances and Service Bindings that the Platform knows about, and none that it
doesn't.

Orphaned Service Instances and Service Bindings might have been created in one
of the following scenarios:
* The Service Broker does not return a response before a request from the
Platform times out (typically 60 seconds). The Service Broker might eventually
succeed in creating a resource, however the Platform might have already
considered the request a failure.
* A synchronous [Provisioning](#provisioning) request fails.
* A call to the
[Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances)
endpoint returns `"state": "failed"` for an asynchronous provisioning or
deprovisioning request.
* A synchronous [Binding](#binding) request fails.
* A call to the
[Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings)
endpoint returns `"state": "failed"` for an asynchronous binding or unbinding
request.
* The Platform encounters an internal error when creating a Service Instance or
Service Binding (for example, saving to the database fails).

To mitigate orphaned Service Instances and Service Bindings, the Platform SHOULD
attempt to delete resources it cannot be sure were successfully created, and
SHOULD keep trying to delete them until the Service Broker responds with a
success. Service Brokers MAY automatically delete any resources they believe to
be orphaned on their own. Note that the Platform MAY allow end users to
determine when orphan mitigation occurs, in order to allow them to investigate
the cause of any failures.

The following table aims to describe when Orphan Mitigation is to be initiated
by the Platform:

| Request | Service Broker Response Status Code | Platform Interpretation Of Response | Orphan Mitigation SHOULD be performed for Service Instances | Orphan Mitigation SHOULD be performed for Service Bindings |
| --- | --- | --- | --- | --- |
| _All_ | 200 | Success (only returned in synchronous mode) | No | No |
| _All_ | 200 with malformed response | Failure | No | No |
| [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) for [Provisioning](#provisioning)/[Deprovisioning](#deprovisioning) | 200 with `"state": "failed"` | Failure | Yes | No |
| [Polling Last Operation for Service Instances](#polling-last-operation-for-service-instances) for [Updating](#updating-a-service-instance) | 200 with `"state": "failed"` | Failure | No | No |
| [Polling Last Operation for Service Bindings](#polling-last-operation-for-service-bindings) for [Binding](#binding)/[Unbinding](#unbinding) | 200 with `"state": "failed"` | Failure | No | Yes |
| _All_ | 201 | Success | No | No |
| [Provisioning](#provisioning) | 201 with malformed response | Failure | Yes | No |
| [Binding](#binding) | 201 with malformed response | Failure | No | Yes |
| _All_ | 202 | Success | No | No |
| [Provisioning](#provisioning) | 202 with malformed response | Failure | Yes | No |
| [Binding](#binding) | 202 with malformed response | Failure | No | Yes |
| [Provisioning](#provisioning)/[Deprovisioning](#deprovisioning) | All other 2xx | Failure | Yes | No |
| [Binding](#binding)/[Unbinding](#unbinding) | All other 2xx | Failure | No | Yes |
| [Updating a Service Instance](#updating-a-service-instance) | All other 2xx | Failure | No | No |
| _All_ | 408 | Client timeout failure (request not received at the server) | No | No |
| _All_ | All other 4xx | Request rejected | No | No |
| [Provisioning](#provisioning)/[Deprovisioning](#deprovisioning) | 5xx | Service Broker error | Yes | No |
| [Binding](#binding)/[Unbinding](#unbinding) | 5xx | Service Broker error | No | Yes |
| [Updating a Service Instance](#updating-a-service-instance) | 5xx | Service Broker error | No | No |
| [Provisioning](#provisioning) | Timeout | Failure | Yes | No |
| [Binding](#binding) | Timeout | Failure | No | Yes |
| _All_ (except [Provisioning](#provisioning) and [Binding](#binding)) | Timeout | Failure | No | No |
