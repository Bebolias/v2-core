# Cannon Overview

- smart contract deployment tool and package manager
- users define Cannonfiles, which specify the desired state of blockchain (local, testnet, or mainnet), for example you might want to deploy a smart contract and invoke a function on it to set some configuration
- you can also import packages to connect your protocol to an exisiting protocol


- then, can use Cannon to build a blockchain into the state specified by the Cannonfile
- the process works the same for local development, testnets, forks and mainnet deployments
- deployments can be shared as packages via the decentralized package manager

# Use Cases for Canon

- Front-end Development: devs can download a package, run it on local node, and retrieve the addresses and ABIs. When ready for production, front-end app can simply use the addresses from the package which correspond to the user's network
- Smart-contract Development: devs can setup environments with all their smart contracts configured however they'd like and also import the other packages for integrations
- QA/Testing: development builds can be used and inspected prior to deployment to ensure implementations are accurate and robust 
- Protocol Deployment, Upgrades and Configuration: when smart contracts are ready for deployment (or upgrade), the same Cannonfiles used in development and testing can be built on remote networks
- Continuous Integration: testing pipelines can rely on Cannon to create nodes for integration and E2E tests
- GitOps: Cannonfiles can be managed in git such that an org can maintain a clear source of trueth for the deployment state

# Package Manger

- builds are created as packages which contain all the deployment results and build settings for your chain
- based on your local system configuration, these packages are uploaded as blobs to IPFS
- you can share packages by either sending the IPFS Qm hash, or by registering the package on-chain with your registry contract

# Hardhat Plug-in

The Hardhat plug-in wraps the command-line tool to automatically use defaults from a project's Hardhat configuration file. If you’re using Cannon with Hardhat, you can install the Hardhat plug-in hardhat-cannon.

More details here: https://usecannon.com/docs/#cannon-commands


# Gnosis-safe plugin

Coming soon (ref: https://usecannon.com/docs/#gnosis-safe-plug-in)

# Build with Cannon

Run the setup command to prepare your development environment:

`cannon setup`

- Cannon relies on IPFS for file storage
- You can run an IPFS node locally (https://docs.ipfs.tech/install/ipfs-desktop/) or rely on a remote pinning service, e.g. Infura ()
