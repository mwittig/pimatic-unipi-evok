# Release History

* 20180320, V0.3.1
    - Dependency updates
    
* 20180112, V0.3.0
    - Support for Evok API 2.0, issues #10 and #12. Thanks to @sedlon
    - Dependency updates
    - Revised README
    - Added section on Trouble Shooting
    - Added Release History
    
* 20161028, V0.2.10
    - Dependency updates
    - Revised source code comments and README
    - Added advisory note on copying to snippets file

* 20160726, V0.2.9
    - Dependency updates
    - Bug fix "plugin is not defined" on device destruction

* 20160525, V0.2.8
    - Fixed error handling for analog output. 
    - Added destroy() method to device class implementations for pimatic 0.9. 
    - Added method to unregister a device from the Update Manager
    - Dependency update. 
    - Added gulp and coffeelint tools for development.
    - Removed _callbackHandler() in favour of builtin closure wrapper (for ... do () =>). 
    - Coding style related changes.
    - Changed travis build descriptor to apply for latest node v4 build
    
* 20160325, V0.2.7
    - Bug fix for auto-discovery: UniPiUpdateManager missing queryAllDevices method

* 20160325, V0.2.6
    - Added auto-discovery for pimatic v0.9
    - Refactoring: Separated device classes to individual files
    - Now, using plugin-commons logging helper
    
* 20160322, V0.2.5
    - Fixed compatibility issue with Coffeescript 1.9 as required for pimatic 0.9
    
* 20160305, V0.2.4
    - Updated to ws@1.0.1 which contain important security fix
    - Added travis build descriptor and build status badge
    
* 20151231, V0.2.3
    - Updated dependency on 'ws'
    
* 20151124, V0.2.2
    - Fixed class name used for relay in `code.snippets` file

* 20151011, V0.2.1
    - Added support for "xOpenedLabel", "xClosedLabel" extensions on UniPiDigitalInput

* 20151011, V0.2.0
    - Improved error logging. The same error is no longer logged repeatedly.
    - Added config-snippets.txt to simplify device configuration

* 20151004, V0.1.2
    - Minor update - package.json
    
* 20151004, V0.1.1
    - Minor update - package.json

* 20151003, V0.1.0
    - Initial Version

    
    
