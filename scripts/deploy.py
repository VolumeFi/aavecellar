  
from brownie import aavecellar, accounts

def main():
    acct = accounts.load("deployer_account")
    name = "Cellar Pool Share Test ETH USDT"
    symbol = "CPST"
    lendingPool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
    u_token = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
    aavecellar.deploy(name, symbol, lendingPool, u_token, {"from":acct})