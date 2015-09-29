# pimatic-unipi

Pimatic Plugin for the [UniPi board](http://www.unipi.technology) based
on the [Evok UniPi API](https://github.com/UniPiTechnology/evok).

## Getting Started

To be able to use the plugin you need to install Evok on the Raspberry Pi
mounted on the UniPi board. Pimatic can either be installed on the same board
on another host on the local network.

## Plugin Configuration

You can load the plugin by editing your `config.json` to include the following
in the `plugins` section. You need to provide the URL of the Evok Web Server.

    {
       "plugin": "unipi-evok",
       "url": "http://unipi.fritz.box"
    }

The plugin has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| url       | -        | String  | URL of the Evok Web Server                  |
| debug     | false    | Boolean | Provide additional debug output if true     |
| timeout   | 20       | Number  | Timeout in seconds for HTTP REST Requests   |

## Device Configuration

Devices must be added manually to the device section of your pimatic config.

### Relay Device

The Relay Device is based on the PowerSwitch device class. You need to provide
the circuit id as shown by Evok.

    {
          "id": "unipi1",
          "class": "UniPiRelay",
          "name": "Relay 1",
          "circuit": "1"
    }

The Relay Device has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| circuit   | "1"      | String  | Circuit id as shown by Evok                 |

The following predicates and actions are supported:
* {device} is turned on|off
* switch {device} on|off


### Digital Input Device

The Digital Input Device is based on the ContactSensor device class. You need
to provide the circuit id as shown by Evok.

    {
          "id": "unipi2",
          "class": "UniPiDigitalInput",
          "name": "Digital Input"
          "circuit": "1"
    }

The Digital Input Device has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| circuit   | "1"      | String  | Circuit id as shown by Evok                 |

The following predicates are supported:
* {device} is opened|closed


### Analog Input Device

The Analog Input Device is based on the Sensor Device device class. You need
to provide the circuit id as shown by Evok.

    {
          "id": "unipi3",
            "class": "UniPiAnalogInput",
          "name": "Analog Input",
          "circuit": "2"
    }

The Analog Input Device has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| circuit   | "1"      | String  | Circuit id as shown by Evok                 |

The Analog Input Device exhibits the following attributes:

| Property      | Unit  | Type    | Acronym | Description                      |
|:--------------|:------|:--------|:--------|:---------------------------------|
| inputVoltage  | V     | Number  | U       | Input Voltage                    |

The following predicates are supported:
* inputVoltage of {device} is equal to | is less than | is greater than {value},
  more comparison operators are supported


### Analog Output Device

The Analog Output Device is based on the DimmerActuator device class.

    {
          "id": "unipi4",
          "class": "UniPiAnalogOutput",
          "name": "Analog Output",
          "circuit": "1"
    }

The Analog Output Device has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| circuit   | "1"      | String  | Circuit id as shown by Evok                 |

The Analog Output Device exhibits the following attributes:

| Property      | Unit  | Type    | Acronym | Description                      |
|:--------------|:------|:--------|:--------|:---------------------------------|
| outputVoltage | V     | Number  | U       | Output Voltage                   |

The following predicates and actions are supported:
* outputVoltage of {device} is equal to | is less than | is greater than {value},
  more comparison operators are supported
* dim {device} to {Value}, where {Value} is 0-100

### Temperature Device

The Temperature Device is based on the TemperatureSensor device class.

    {
      "id": "unipi5",
      "class": "UniPiTemperature",
      "name": "Temperature",
      "circuit": "2832ECD906000025"
    }

The Temperature Device has the following configuration properties:

| Property  | Default  | Type    | Description                                 |
|:----------|:---------|:--------|:--------------------------------------------|
| circuit   | "1"      | String  | Circuit id as shown by Evok                 |

The Temperature Device exhibits the following attributes:

| Property      | Unit  | Type    | Acronym | Description                      |
|:--------------|:------|:--------|:--------|:---------------------------------|
| temperature   | °C    | Number  | T       | Temperature                      |

The following predicates are supported:
* temperature of {device} is equal to | is less than | is greater than {value},
  more comparison operators are supported

## Acknowledgments

I would like to thank [UniPi.technology](http://www.unipi.technology) for providing me with a board for development. 
In particular, I would like to thank Tomáš Hora for his excellent support!