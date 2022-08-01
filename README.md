# Namebase-DSLD

### Namebase Decentralised Domain Names

These are the smart contracts that will power the Namebase DSLDs on an EVM (tbd). SLDs will conform to the ERC-721 standard so they can be traded efficiently on compatible marketplaces.


### Installing Forge

_Having issues? See the [troubleshooting section](#troubleshooting-installation)_.

_For Windows, I would recommend installing [WSL](https://docs.microsoft.com/en-us/windows/wsl/install)_

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

If you do not want to use the redirect, feel free to manually download the foundryup installation script from [here](https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/install).

Then, run `foundryup` in a new terminal session or after reloading your `PATH`.

Other ways to use `foundryup`, and other documentation, can be found [here](./foundryup). Happy forging!

## Installing from Source

For people that want to install from source, you can do so like below:

```sh
git clone https://github.com/foundry-rs/foundry
cd foundry
# install cast + forge
cargo install --path ./cli --profile local --bins --locked --force
# install anvil
cargo install --path ./anvil --profile local --locked --force
```

Or via `cargo install --git https://github.com/foundry-rs/foundry --profile local --locked foundry-cli anvil`.

## Installing for CI in Github Action

See [https://github.com/foundry-rs/foundry-toolchain](https://github.com/foundry-rs/foundry-toolchain) GitHub Action.

## Installing via Docker

Foundry maintains a [Docker image repository](https://github.com/foundry-rs/foundry/pkgs/container/foundry).

You can pull the latest release image like so:

```sh
docker pull ghcr.io/foundry-rs/foundry:latest
```

For examples and guides on using this image, see the [Docker section](https://book.getfoundry.sh/tutorials/foundry-docker.html) in the book.

### Running Forge Tests

Just run 

```sh
Forge Test
```
in the terminal / console.

