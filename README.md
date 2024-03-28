# catalog-cosign-contracts (public)


```
      ___                                                                                               __                          __
     /\_ \                                           __                                                /\ \__                      /\ \__
  ___\//\ \      __              ___    ___     ____/\_\     __     ___              ___    ___     ___\ \ ,_\  _ __    __      ___\ \ ,_\   ____
 /'___\\ \ \   /'_ `\  _______  /'___\ / __`\  /',__\/\ \  /'_ `\ /' _ `\  _______  /'___\ / __`\ /' _ `\ \ \/ /\`'__\/'__`\   /'___\ \ \/  /',__\
/\ \__/ \_\ \_/\ \L\ \/\______\/\ \__//\ \L\ \/\__, `\ \ \/\ \L\ \/\ \/\ \/\______\/\ \__//\ \L\ \/\ \/\ \ \ \_\ \ \//\ \L\.\_/\ \__/\ \ \_/\__, `\
\ \____\/\____\ \____ \/______/\ \____\ \____/\/\____/\ \_\ \____ \ \_\ \_\/______/\ \____\ \____/\ \_\ \_\ \__\\ \_\\ \__/.\_\ \____\\ \__\/\____/
 \/____/\/____/\/___L\ \        \/____/\/___/  \/___/  \/_/\/___L\ \/_/\/_/         \/____/\/___/  \/_/\/_/\/__/ \/_/ \/__/\/_/\/____/ \/__/\/___/
                 /\____/                                     /\____/
                 \_/__/                                      \_/__/



```

Solidity contract repo for Catalog Cosign Protocol

## Deployments

#### Base Mainnet (8453)

| Contract Name        | Address                                   | Network   | Deployment Date | Additional Info |
|----------------------|-------------------------------------------|-----------|-----------------|-----------------|
| CatalogCosigns            | 0x15e57847c5EEE553E0eAa247De0dFFeF28DD68eb                         | Base Mainnet  | 2023-12-12      | Proxy Contract               |
| CatalogCosignsImplementation            | 0xa725a1A21134cBEE4704D26B860512c3D85199f9                               | Base Mainnet   | 2023-12-12      | Implementation V1              |
| CatalogCosignsImplementation            | 0x1203e72Fcb8A5e48f6be58d1f62185a8E84F792F                               | Base Mainnet   | 2024-02-29      | Implementation V2              |

#### Base Sepolia (84532)

| Contract Name        | Address                                   | Network   | Deployment Date | Additional Info |
|----------------------|-------------------------------------------|-----------|-----------------|-----------------|
| CatalogCosigns            | 0xA9d06704e872C868be343C8DDBb2B412d17dea6c                         | Base Sepolia  | 2023-12-12      | Proxy Contract               |
| CatalogCosignsImplementation            | 0x65a87A9a098e4F1B990f21C1D48997Ac79546212                               | Base Sepolia   | 2023-12-12      | Implementation V1              |
| CatalogCosignsImplementation            | 0x0A5A8eD6f7C6278Df1199D69be902E355293778F                               | Base Sepolia   | 2024-02-29      | Implementation V2              |


## Setup

Ensure [Foundry](https://getfoundry.sh) is installed on your local machine.

## Usage

### Install

```shell
$ forge install
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```


## License

[MIT](LICENSE)

## Info / Contact

cosigns is under active development, this repository hosts publicly accessible verified deployments.

please reach out via the [catalog discord](https://catalog.community) for help with building on cosigns.
