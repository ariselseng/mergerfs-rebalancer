# mergerfs-rebalancer
A simple script to move files from one folder to another. Made with [mergerfs](https://github.com/trapexit/mergerfs) in mind.
It only moves files that are not in use, and modified before a certain time (default: 60min).
## Example
mergerfs-rebalancer/run.sh  [-t 180] -a /source -b /target
