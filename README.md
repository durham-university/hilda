HILDA
======

Hydra Image Loader / Disseminator Application. Interface for loading digital objects into repository, creating structural metadata, attaching descriptive metadata, attaching dissemination method(s), attaching digital preservation programme and so on.

See [HILDA in Smartie](https://smartie.dur.ac.uk/display/HP/HILDA)

Development notes
=================

Hilda is split into two parts. The base part is the general ingestion framework, the Rails application to manage it and some general purpose ingestion modules. This is by far the larger of the two parts.

The other part is in the folder hilda_durham and contains modules that are more specific to the service structure in Durham. At the moment it mostly just includes modules that interface with other Durham services such as Schmit, Oubliette and Trifle.

Each of the two parts contain a test_app for testing. The hilda_durham test_app is the more interesting one as it can actually ingest test material into the other services, or test versions of them. On the other hand it requires these services to be running to work. 
The test_app is configured to mount all the other required applications as Rails engines so you can start all of them in one Rails server. The Gemfile for the test_app also specifies paths for the other Engines, which makes it easy to develop them and test them all working together. 
