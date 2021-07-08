# Open Service Broker API Profile (master - might contain changes that are not yet released)

## Abstract

The [Open Service Broker API specification](spec.md) allows for extensions
and variations based on the environments in which it is being used; this
document contains the suggested usage pattern for some of those variants.

While use of this profile is OPTIONAL, an implementation is not compliant
with this profile if it fails to satisfy one or more of the MUST, SHALL
or REQUIRED level requirements defined herein.

## Table of Contents

- [Notations and Terminology](#notations-and-terminology)
  - [Notational Conventions](#notational-conventions)
  - [Terminology](#terminology)
- [Additional Headers](#additional-headers)
  - [Cloud Foundry Info Location Header](#cloud-foundry-info-location-header)
- [Originating Identity Header](#originating-identity-header)
  - [Cloud Foundry Originating Identity Header](#cloud-foundry-originating-identity-header)
  - [Kubernetes Originating Identity Header](#kubernetes-originating-identity-header)
- [Context Object](#context-object)
  - [Context Object Properties](#context-object-properties)
  - [Cloud Foundry Context Object](#cloud-foundry-context-object)
  - [Kubernetes Context Object](#kubernetes-context-object)
- [Bind Resource Object](#bind-resource-object)
  - [Cloud Foundry Bind Resource Object](#cloud-foundry-bind-resource-object)
- [Service Metadata](#service-metadata)
  - [Cloud Foundry Service Metadata](#cloud-foundry-service-metadata)
- [Catalog Extensions](#catalog-extensions)
  - [Cloud Foundry Catalog Extensions](#cloud-foundry-catalog-extensions)

## Notations and Terminology

### Notational Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to
be interpreted as described in [RFC 2119]( https://tools.ietf.org/html/rfc2119).

### Terminology

Please refer to terminology defined by the
[Open Service Broker API specification](spec.md#terminology).


## Additional Headers

### Cloud Foundry Info Location Header

The `X-API-Info-Location` header is used to provide Service Brokers with an
endpoint that can be used to fetch information about the specific Cloud Foundry
deployment from which the request originated.

The header consists of a `value` string, where the `value` is a Base64 encoded
serialized JSON object.

The following properties MUST appear within the JSON encoded `value`:

| Property | Type | Description |
| --- | --- | --- |
| info_location_url | string | The URL of an endpoint that can be used to fetch information about the Cloud Foundry deployment from which the request originated. |

Platforms MAY include additional properties.

For example, a `value` of:
```json
{
  "info_location_url": "https://api.platform.example.com/v2/info"
}
```
would appear in the HTTP Header as:
```
X-API-Info-Location: ewogICJpbmZvX2xvY2F0aW9uX3VybCI6ICJodHRwczovL2FwaS5wbGF0Zm9ybS5leGFtcGxlLmNvbS92Mi9pbmZvIgp9
```


## Originating Identity Header

In the [Open Service Broker API specification](spec.md) it defines an
additional HTTP Header that can be included in messages from the Platform
to identify the user that requested the action to be taken.

The header consists of two parts: a `platform` string and `value` string,
where the `value` is a Base64 encoded serialized JSON object.
Both parts will vary based on the Platform which is being used. The
following sections define the values to be used based on the Platform
and which properties are expected to appear in the `value` JSON.

Note that when both the originating identity HTTP Header and the Context
object appear in the same message the `platform` value MUST be the same
for both.

### Cloud Foundry Originating Identity Header

*`platform` Value*: `cloudfoundry`

The following properties MUST appear within the JSON encoded `value`:

| Property | Type | Description |
| --- | --- | --- |
| user_id | string | The `user_id` value from the Cloud Foundry JWT token. |

Platforms MAY include additional properties.

For example, a `value` of:
```json
{
  "user_id": "683ea748-3092-4ff4-b656-39cacc4d5360"
}
```
would appear in the HTTP Header as:
```
X-Broker-API-Originating-Identity: cloudfoundry eyANCiAgInVzZXJfaWQiOiAiNjgzZWE3NDgtMzA5Mi00ZmY0LWI2NTYtMzljYWNjNGQ1MzYwIg0KfQ==
```

### Kubernetes Originating Identity Header

*`platform` Value*: `kubernetes`

The following properties MUST appear within the JSON encoded `value`:

| Property | Type | Description |
| --- | --- | --- |
| username | string | The `username` property from the Kubenernetes `user.info` object. |
| uid | string | The `uid` property from the Kubenernetes `user.info` object. |
| groups | array-of-strings | The `groups` property from the Kubenernetes `user.info` object. |
| extra | map-of-array-of-strings | The `extra` property from the Kubernetes `user.info` object. |

Platforms MAY include additional properties.

For example, a `value` of:
```json
{
  "username": "duke",
  "uid": "c2dde242-5ce4-11e7-988c-000c2946f14f",
  "groups": [ "admin", "dev" ],
  "extra": {
    "mydata": [ "data1", "data3" ]
  }
}
```
would appear in the HTTP Header as:
```
X-Broker-API-Originating-Identity: kubernetes ew0KICAidXNlcm5hbWUiOiAiZHVrZSIsDQogICJ1aWQiOiAiYzJkZGUyNDItNWNlNC0xMWU3LTk4OGMtMDAwYzI5NDZmMTRmIiwNCiAgImdyb3VwcyI6IFsgImFkbWluIiwgImRldiIgXSwNCiAgImV4dHJhIjogew0KICAgICJteWRhdGEiOiBbICJkYXRhMSIsICJkYXRhMyIgXQ0KICB9DQp9
```


## Context Object

In the [Open Service Broker API specification](spec.md) there are certain
message flows that include a `context` property. This property is defined
as an opaque JSON object that is meant to contain contextual information
about the environment in which the Platform or Application is executing.

While the `context` property is defined as an opaque JSON object, in practice,
it is often useful and necessary for there to be an agreed upon set of
properties to ensure a common understanding of this data between the
Platform and the Service Brokers.

### Context Object Properties

The list of properties within the Context Object can vary depending on
which Service Broker API is being invoked and which Platform is being used.
This section will define a set of properties for each Platform and specify
when each is meant to be used. Platforms MAY choose to provide additional
properties beyond the ones defined in this document.

Each property will include the version of the Open Service Broker
API in which it was introduced. For any API call in which that property
is mandatory, it is only mandatory for the specified version of the
specification or higher.

Aside from the Platform specific properties, defined in the following
sections, there is one common property called `platform` that
MUST also appear within `context` to indicate which Platform is being used.

The `platform` property MUST be a `string` and serialized as follows:
```
"platform": "platform-string-here"
```

Each section below will define the `platform` value that MUST be used based
on the Platform and the set of additional properties that MUST be present.

Note that when both the originating identity HTTP Header and the Context
object appear in the same message the `platform` value MUST be the same
for both.

To enable support for Platforms to send an update request for a Service Instance
containing only contextual data, a Service Broker MUST declare support by
including `"allow_context_updates": true` in its
[catalog endpoint](spec.md#catalog-management).

### Cloud Foundry Context Object

*`platform` Property Value*: `cloudfoundry`

The following properties are defined for usage within a Cloud Foundry
deployment:

- `organization_guid`

  Version: 2.11

  The GUID of the organization that a Service Instance is associated with.
  This property MUST be a non-empty string serialized as follows:
  ```
  "organization_guid": "organization-guid-here"
  ```
  For example:
  ```
  "organization_guid": "1113aa0-124e-4af2-1526-6bfacf61b111"
  ```

- `organization_name`

  Version: 2.15

  The name of the organization that a Service Instance is associated with.
  Note that the name of an organization in Cloud Foundry MAY be changed.
  This property MUST be a non-empty string serialized as follows:
  ```
  "organization_name": "organization-name-here"
  ```
  For example:
  ```
  "organization_name": "system"
  ```

- `organization_annotations`

  Version: 2.16

  The [annotations](http://v3-apidocs.cloudfoundry.org/version/3.69.0/index.html#metadata) attached to the organization that a Service Instance is associated with.
  Note that the annotations of an organization in Cloud Foundry MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "organization_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "organization_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```


- `space_guid`

  Version: 2.11

  The GUID of the space that a Service Instance is associated with.
  This property MUST be a non-empty string serialized as follows:
  ```
  "space_guid": "space-guid-here"
  ```
  For example:
  ```
  "space_guid": "aaaa1234-da91-4f12-8ffa-b51d0336aaaa"
  ```

- `space_name`

  Version: 2.15

  The name of the space that a Service Instance is associated with.
  Note that the name of a space in Cloud Foundry MAY be changed.
  This property MUST be a non-empty string serialized as follows:
  ```
  "space_name": "space-name-here"
  ```
  For example:
  ```
  "space_name": "development"
  ```

- `space_annotations`

  Version: 2.16

  The [annotations](http://v3-apidocs.cloudfoundry.org/version/3.69.0/index.html#metadata) attached to the space that a Service Instance is associated with.
  Note that the annotations of a space in Cloud Foundry MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "space_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "space_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```


- `instance_name`

  Version: 2.15

  The name of the Service Instance.
  Note that the name of a Service Instance in Cloud Foundry MAY be changed.
  This property MUST be a non-empty string serialized as follows:
  ```
  "instance_name": "instance-name-here"
  ```
  For example:
  ```
  "instance_name": "my-db"
  ```

The following table specifies which properties will appear in each API.
All properties specified are REQUIRED unless otherwise noted.

| Request API | Properties |
| --- | --- |
| `PUT /v2/service_instances/:instance_id` | `organization_guid`, `organization_name`, `space_guid`, `space_name`, `instance_name` |
| `PATCH /v2/service_instances/:instance_id` | `organization_guid`, `organization_name`, `space_guid`, `space_name`, `instance_name` |
| `PUT /v2/service_instances/:instance_id/service_bindings/:binding_id` | `organization_guid`, `organization_name`, `space_guid`, `space_name` |

The following example shows a `context` object that might appear as part of a
Cloud Foundry API call:
  ```
  "context": {
    "platform": "cloudfoundry",
    "organization_guid": "1113aa0-124e-4af2-1526-6bfacf61b111",
    "organization_name": "system",
    "space_guid": "aaaa1234-da91-4f12-8ffa-b51d0336aaaa",
    "space_name": "development",
    "instance_name": "my-db"
  }
  ```

- `instance_annotations`

  Version: 2.16

  The [annotations](http://v3-apidocs.cloudfoundry.org/version/3.69.0/index.html#metadata) attached to the Service Instance.
  Note that the annotations of a Service Instance in Cloud Foundry MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "instance_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "instance_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```


### Kubernetes Context Object

*`platform` Property Value*: `kubernetes`

The following properties are defined for usage within a Kubernetes deployment:

- `namespace`

  Version: 2.11

  The name of the Kubernetes namespace in which the Service Instance
  will be visible. This property MUST be a non-empty string serialized
  as follows:

  ```
  "namespace": "namespace-name-here"
  ```
  For example:
  ```
  "namespace": "testing"
  ```

- `namespace_annotations`

  Version: 2.16

  The [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) attached to the namespace in which the Service Instance will be visible.
  Note that the annotations of a namespace in Kubernetes MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "namespace_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "namespace_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```

- `instance_annotations`

  Version: 2.16

  The [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) attached to the Service Instance.
  Note that the annotations of a Service Instance in Kubernetes MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "instance_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "instance_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```



- `clusterid`

  Version: 2.14

  The unique identifier for the Kubernetes cluster from which the request
  was sent. This property can be useful when a Service Broker tries to
  call back to a Platform that is managing multiple Kubernetes clusters.
  Typically this value will be static for the lifetime of the cluster,
  however, that is a Platform implementation choice. Brokers ought to take
  care that, while atypical, it is possible for the value to change over
  time.

  This property MUST be a non-empty string serialized as follows:

  ```
  "clusterid": "id-goes-here"
  ```
  For example:
  ```
  "clusterid": "644e1dd7-2a7f-18fb-b8ed-ed78c3f92c2b"
  ```


- `instance_name`

  Version: 2.15

  The name of the Service Instance.
  Note that the name of a Service Instance in Kubernetes MAY be changed.
  This property MUST be a non-empty string serialized as follows:
  ```
  "instance_name": "instance-name-here"
  ```
  For example:
  ```
  "instance_name": "my-db"
  ```


The following table specifies which properties will appear in each API.
All properties specified are REQUIRED unless otherwise noted.

| Request API | Properties |
| --- | --- |
| `PUT /v2/service_instances/:instance_id` | `namespace`, `clusterid`, `instance_name` |
| `PATCH /v2/service_instances/:instance_id` | `namespace`, `clusterid`, `instance_name` |
| `PUT /v2/service_instances/:instance_id/service_bindings/:binding_id` | `namespace`, `clusterid` |

Example:

The following example shows a `context` property that might appear as
part of a Kubernetes API call:
  ```
  "context": {
    "platform": "kubernetes",
    "namespace": "development",
    "clusterid": "8263feba-9b8a-23ae-99ed-abcd1234feda"
  }
  ```

## Bind Resource Object

In the [Open Service Broker API specification](spec.md), requests to
[create a Service Binding](spec.md#binding) can contain a `bind_resource`
object in which Platforms MAY choose to add additional fields.

### Cloud Foundry Bind Resource Object

The Cloud Foundry Bind Resource Object supports the Cloud Foundry [Service Binding](https://docs.cloudfoundry.org/devguide/services/application-binding.html) and the [Service Key](https://docs.cloudfoundry.org/devguide/services/service-keys.html) developer requests. The credentials returned by the Service Binding endpoints MAY be references to credentials stored in [CredHub](https://docs.cloudfoundry.org/credhub/index.html), the component designed for centralized credential management in Cloud Foundry. Service Brokers are then responsible for writing credentials into CredHub and granting read permissions to a bound application or a specified client. See more details into [Credhub documentation](https://github.com/cloudfoundry-incubator/credhub/blob/master/docs/secure-service-credentials.md#service-brokers). The provisioning of CredHub access for Service Brokers is performed out of band and is out of scope of this specification.

The following properties are defined for usage within a Cloud Foundry
deployment:

- `space_guid`
  This OPTIONAL property is the GUID of a space that a Service Binding is
  associated with. If present, this property MUST be a non-empty string
  serialized as follows:
  ```
  "space_guid": "space-guid-here"
  ```
  For example:
  ```
  "space_guid": "15823972-c216-4ba5-9f3f-e75b0b891297"
  ```

- `app_annotations`

  Version: 2.16

  The [annotations](http://v3-apidocs.cloudfoundry.org/version/3.69.0/index.html#metadata) attached to the application that a Service Binding is associated with.
  Note that the annotations of an application in Cloud Foundry MAY be changed.
  This OPTIONAL property holds an object with the annotations key/value pairs. If present, this property MUST be an object, with zero or more properties as follows:

  ```
  "app_annotations": { "prefix-here.org/name-here":"value-here" }
  ```
  For example:
  ```
  "app_annotations": { "myprovider.com/send-alerts-to-email":"me@mycompany.com" }
  ```

- `credential_client_id`

  Version: 2.16

  When the Bind Resource Object is the result of a Cloud Foundry [service key](https://docs.cloudfoundry.org/devguide/services/service-keys.html) developer request, then the Cloud Cloundry CredHub client id is provided. This supports Service Brokers that MAY choose use to securely store Service Binding credentials, and return [credhub references](https://github.com/cloudfoundry-incubator/credhub/blob/master/docs/secure-service-credentials.md#service-brokers) Service Binding responses instead of plain credentials values. In this case, the provided client MUST be granted permission by the Service Broker to read the returned credentials reference.
  This OPTIONAL property holds a string with the client id that MUST be granted read permissions. If present, this property MUST be a non empty string as follows:

  ```
    "credential_client_id": "client_id-value-here"
  ```
  For example:
  ```
    "credential_client_id": "cc_service_key_client"
  ```

The following example shows a `bind_resource` object that might appear as part
of a Cloud Foundry API call resulting from a Service Binding developer request:
  ```
  "bind_resource": {
    "app_guid": "5e76c9bf-d5e3-46bf-9877-6d8dddfc8a45",
    "space_guid": "15823972-c216-4ba5-9f3f-e75b0b891297"
  }
  ```

The following example shows a `bind_resource` object that might appear as part
of a Cloud Foundry API call resulting from a Service Key developer request:
  ```
  "bind_resource": {
    "credential_client_id": "cc_service_key_client"
  }
  ```

## Service Metadata

While the [specification](spec.md) does not mandate the property names used
in the `metadata` objects, it is RECOMMENDED that the following names
be used when possible in an attempt to provide some degree of interoperability
and consistency.

Please note that in addition to service metadata returned from [catalog endpoint](spec.md#catalog-management), 
Service Brokers MAY also expose service-instance-specific metadata through the
[ServiceInstanceMetadata](spec.md#service-instance-metadata) structure returned by Service Brokers 
in the [Provisioning](spec.md#provisioning) endpoint with updates potentially published 
in the [Updating](spec.md#updating-a-service-instance) and [Fetching a Service Instance](spec.md#fetching-a-service-instance) endpoints.

#### Service Metadata Fields

| Service Broker API Field | Type | Description |
| --- | --- | --- |
| metadata.displayName | string | The name of the service to be displayed in graphical clients. |
| metadata.imageUrl | string | The URL to an image or a data URL containing an image. |
| metadata.longDescription | string | Long description. |
| metadata.providerDisplayName | string | The name of the upstream entity providing the actual service. |
| metadata.documentationUrl | string | Link to documentation page for the service. |
| metadata.supportUrl | string | Link to support page for the service. |

#### Plan Metadata Fields
| Service Broker API Field | Type | Description |
| --- | --- | --- |
| metadata.bullets | array-of-strings | Features of this plan, to be displayed in a bulleted-list. |
| metadata.costs | array-of-objects | An array-of-objects that describes the costs of a service, in what currency, and the unit of measure. If there are multiple costs, all of them could be billed to the user (such as a monthly + usage costs at once). |
| metadata.displayName | string | Name of the plan to be displayed to clients. |

#### Cost Object
This object describes the costs of a service, in what currency, and the unit
of measure.

| Field | Type | Description |
| --- | --- | --- |
| amount* | object | An array of pricing in various currencies for the cost type as key-value pairs where key is currency code and value (as a float) is currency amount. |
| unit* | string | Display name for type of cost, e.g. Monthly, Hourly, Request, GB. |

\* Fields with an asterisk are REQUIRED.

For example:
```
"costs": [
  {
    "amount": {
      "usd": 649.0
    },
    "unit": "MONTHLY"
  }
]
```

#### Example Service Broker Response Body

The example below contains a catalog of one service, having one Service Plan.
Of course, a Service Broker can offer a catalog of many services, each having
many plans.

```json
{
  "services":[
    {
      "id":"766fa866-a950-4b12-adff-c11fa4cf8fdc",
      "name":"cloudamqp",
      "description":"Managed HA RabbitMQ servers in the cloud.",
      "requires":[],
      "tags":[
        "amqp",
        "rabbitmq",
        "messaging"
      ],
      "metadata":{
        "displayName":"CloudAMQP",
        "imageUrl":"https://d33na3ni6eqf5j.cloudfront.net/app_resources/18492/thumbs_112/img9069612145282015279.png",
        "longDescription":"Managed, highly available, RabbitMQ clusters in the cloud.",
        "providerDisplayName":"84codes AB",
        "documentationUrl":"http://docs.cloudfoundry.com/docs/dotcom/marketplace/services/cloudamqp.html",
        "supportUrl":"http://www.cloudamqp.com/support.html"
      },
      "dashboard_client":{
        "id":"p-mysql-client",
        "secret":"p-mysql-secret",
        "redirect_uri":"http://p-mysql.example.com/auth/create"
      },
      "plans":[
        {
          "id":"024f3452-67f8-40bc-a724-a20c4ea24b1c",
          "name":"bunny",
          "description":"A mid-sided plan.",
          "metadata":{
            "bullets":[
              "20 GB of messages",
              "20 connections"
            ],
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
            "displayName":"Big Bunny"
          }
        }
      ]
    }
  ]
}
```

### Cloud Foundry Service Metadata

In addition to the metadata described in [Service Metadata](#service-metadata),
Service Brokers MAY also expose the following fields to enable Cloud Foundry
specific behaviour.


#### Service Metadata Fields

| Broker API Field | Type | Description |
| --- | --- | --- |
| metadata.shareable | boolean | Allows Service Instances to be shared across orgs and spaces. |

## Catalog Extensions

In addition to the fields described in the [Catalog](spec.md#catalog-management),
Service Brokers MAY also expose the following fields to enable Platform specific behaviour.

#### Cloud Foundry Catalog Extensions

| Field | Type | Description |
| --- | --- | --- |
| services[n].dashboard_client | [DashboardClient](#dashboard-client-object) | Contains the data necessary to activate the Dashboard SSO feature for this service. |

##### Dashboard Client Object

| Response Field | Type | Description |
| --- | --- | --- |
| id* | string | The id of the OAuth client that the dashboard will use. If present, MUST be a non-empty string. |
| secret* | string | A secret for the dashboard client. If present, MUST be a non-empty string. |
| redirect_uri | string | A URI for the service dashboard. Validated by the OAuth token server when the dashboard requests a token. |

\* Fields with an asterisk are REQUIRED.

#### Example Catalog

```
{
  "services": [{
    "name": "fake-service",
    "id": "acb56d7c-XXXX-XXXX-XXXX-feb140a59a66",
    "description": "A fake service.",
    "dashboard_client": {
      "id": "398e2f8e-XXXX-XXXX-XXXX-19a71ecbcf64",
      "secret": "277cabb0-XXXX-XXXX-XXXX-7822c0a90e5d",
      "redirect_uri": "http://localhost:1234"
    }
  }]
}
```
