# AAVE Cellar

## Testing and Development on testnet

### Dependencies
* [nodejs](https://nodejs.org/en/download/) - >=v8, tested with version v14.15.4
* [python3](https://www.python.org/downloads/release/python-368/) from version 3.6 to 3.8, python3-dev
* [brownie](https://github.com/iamdefinitelyahuman/brownie) - tested with version [1.14.6](https://github.com/eth-brownie/brownie/releases/tag/v1.14.6)
* ganache-cli

Run Ganache-cli mainnet-fork environment

```bash
ganache-cli --fork https://mainnet.infura.io/v3/#{YOUR_INFURA_KEY} -p 7545
```

Add local network setting to brownie

```bash
brownie networks add Development local host=http://127.0.0.1 accounts=10 evm_version=istanbul fork=mainnet port=7545 mnemonic=brownie cmd=ganache-cli timeout=300
```

Deploy on local ganache-cli network

```bash
brownie run scripts/deploy.py --network local
```

Deploy on mainnet

```bash
brownie run scripts/deploy.py --network mainnet
```

### Running the Tests
```bash
brownie test --network local
```

### Reinvest
```
function reinvest(Bytes[256] route, uint256 minPrice)
```

`route` is swap route by UniswapV3. The last effective token is the new asset.

The meaning of route bytes are as follows.

| Offset(Byte) | Route Data Meaning |
| - | - |
| 0 - 31 | `Token0` |
| 32 - 63 | Fee level of Uniswap V3 from original asset token to `Token0` |
| 64 - 95 | `Token1` or all below `0` if `Token0` is the new asset token |
| 96 - 127 | Fee level of Uniswap V3 from `Token0` to `Token1` |
| 128 - 159 | `Token2` or all below `0` if `Token1` is the new asset token |
| 160 - 191 | Fee level of Uniswap V3 from `Token1` to `Token2` |
| 192 - 223 | `Token3` or all below `0` if `Token2` is the new asset token |
| 224 - 255 | Fee level of Uniswap V3 from `Token2` to `Token3` |

`minPrice` is a limit of the ratio of the new token amount to the old token amount in 18 decimal digits.
For example, if the old token is USDC and the new token is WETH, WETH price is 1000USD/WETH at that time, 6 decimal digits for USDC, 18 decimal digits for WETH, 5% slippage, `minPrice` is as follows.

```
minPrice = 10 ** 18 / (1000 * 10 ** 6) * (95 / 100) * 10 ** 18
```