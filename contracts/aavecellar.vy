# @version 0.3.0

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

name: public(String[64])
symbol: public(String[32])

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)

u_token: public(address)
a_token: public(address)
lendingPool: public(address)
owner: public(address)
validator: public(HashMap[address, bool])
adjuster: public(HashMap[address, bool])
serviceFee: public(uint256)

APPROVE_MID: constant(Bytes[4]) = method_id("approve(address,uint256)")
TRANSFER_MID: constant(Bytes[4]) = method_id("transfer(address,uint256)")
TRANSFERFROM_MID: constant(Bytes[4]) = method_id("transferFrom(address,address,uint256)")
DEPOSIT_MID: constant(Bytes[4]) = method_id("deposit(address,uint256,address,uint16)")
GRD_MID: constant(Bytes[4]) = method_id("getReserveData(address)")
EIS_MID: constant(Bytes[4]) = method_id("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")
CR_MID: constant(Bytes[4]) = method_id("claimRewards(address[],uint256,address)")
SWAPROUTER: constant(address) = 0xE592427A0AEce92De3Edee1F18E0157C05861564
INCENTIVES_CONTROLLER: constant(address) = 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5
stkAAVE: constant(address) = 0x4da27a545c0c5B758a6BA100e3a049001de870f5
AAVE: constant(address) = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9
WETH: constant(address) = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
FEE_DOMINATOR: constant(uint256) = 10000

interface LendingPool:
    def withdraw(asset: address, amount: uint256, to: address): nonpayable

interface ERC20:
    def balanceOf(_to: address) -> uint256: view

@external
def __init__(_name: String[64], _symbol: String[32], _lendingPool: address, _uToken: address):
    self.name = _name
    self.symbol = _symbol
    self.lendingPool = _lendingPool
    self.u_token = _uToken
    self.serviceFee = 50
    response: Bytes[256] = raw_call(
        _lendingPool,
        concat(
            GRD_MID,
            convert(_uToken, bytes32)
        ),
        max_outsize=256
    )
    _a_token: address = convert(convert(slice(response, 224, 32), uint256), address)
    self.a_token = _a_token
    self.owner = msg.sender
    self.validator[msg.sender] = True
    self.adjuster[msg.sender] = True

@internal
def get_atoken(uToken: address) -> address:
    response: Bytes[256] = raw_call(
        self.lendingPool,
        concat(
            GRD_MID,
            convert(uToken, bytes32)
        ),
        max_outsize=256
    )
    return convert(convert(slice(response, 224, 32), uint256), address)

@internal
def _mint(_to: address, _value: uint256):
    assert _to != ZERO_ADDRESS, "mint to zero address"
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    log Transfer(ZERO_ADDRESS, _to, _value)

@internal
def _burn(_to: address, _value: uint256):
    assert _to != ZERO_ADDRESS, "burn from zero address"
    self.totalSupply -= _value
    self.balanceOf[_to] -= _value
    log Transfer(_to, ZERO_ADDRESS, _value)

@internal
def safe_approve(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            APPROVE_MID,
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed approve
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed approve

@internal
def safe_transfer(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFER_MID,
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transfer
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed transfer

@internal
def safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFERFROM_MID,
            convert(_from, bytes32),
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transfer from
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed transfer from

@internal
def _deposit(u_token: address, amount: uint256):
    _lendingPool: address = self.lendingPool
    self.safe_approve(u_token, _lendingPool, amount)
    raw_call(
        _lendingPool,
        concat(
            DEPOSIT_MID,
            convert(u_token, bytes32),
            convert(amount, bytes32),
            convert(self, bytes32),
            convert(0, bytes32)
        )
    )

@internal
def _token2Token(fromToken: address, toToken: address, feeLevel: uint256, tokens2Trade: uint256, deadline: uint256) -> uint256:
    if fromToken == toToken:
        return tokens2Trade
    self.safe_approve(fromToken, SWAPROUTER, tokens2Trade)
    _response: Bytes[32] = raw_call(
        SWAPROUTER,
        concat(
            EIS_MID,
            convert(fromToken, bytes32),
            convert(toToken, bytes32),
            convert(feeLevel, bytes32),
            convert(self, bytes32),
            convert(deadline, bytes32),
            convert(tokens2Trade, bytes32),
            convert(0, bytes32),
            convert(0, bytes32)
        ),
        max_outsize=32
    )
    tokenBought: uint256 = convert(_response, uint256)
    self.safe_approve(fromToken, SWAPROUTER, 0)
    assert tokenBought > 0, "Error Swapping Token"
    return tokenBought

@external
@pure
def decimals() -> uint256:
    return 18

@external
def transfer(_to : address, _value : uint256) -> bool:
    assert _to != ZERO_ADDRESS # dev: zero address
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    return True

@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    assert _to != ZERO_ADDRESS # dev: zero address
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowance[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    return True

@external
def approve(_spender : address, _value : uint256) -> bool:
    assert _value == 0 or self.allowance[msg.sender][_spender] == 0
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True

@external
def increaseAllowance(_spender: address, _value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender]
    allowance += _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True

@external
def decreaseAllowance(_spender: address, _value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender]
    allowance -= _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True

@external
def deposit(amount: uint256):
    _uToken: address = self.u_token
    self.safe_transfer_from(_uToken, msg.sender, self, amount)
    fee: uint256 = amount * self.serviceFee / FEE_DOMINATOR
    self.safe_transfer(_uToken, self.owner, fee)
    real_amount: uint256 = amount - fee
    a_token_balance: uint256 = ERC20(self.a_token).balanceOf(self)
    if a_token_balance == 0:
        self._mint(msg.sender, real_amount)
    else:
        self._mint(msg.sender, real_amount * self.totalSupply / a_token_balance)
    self._deposit(_uToken, real_amount)

@external
def withdraw(amount: uint256):
    LendingPool(self.lendingPool).withdraw(self.u_token, amount * ERC20(self.a_token).balanceOf(self) / self.totalSupply, self)
    self._burn(msg.sender, amount)

@external
def reinvest(route: Bytes[256], minPrice: uint256):
    assert self.validator[msg.sender], "Not validator"
    _lendingPool: address = self.lendingPool
    _a_token: address = self.a_token
    amount: uint256 = ERC20(_a_token).balanceOf(self)
    old_amount: uint256 = amount
    _uToken: address = self.u_token
    self.safe_approve(_a_token, _lendingPool, amount)
    LendingPool(_lendingPool).withdraw(_uToken, amount, self)
    for i in range(4):
        uToken: address = convert(convert(slice(route, i * 64, 32), uint256), address)
        feeLevel: uint256 = convert(slice(route, i * 64 + 32, 32), uint256)
        if uToken == ZERO_ADDRESS:
            assert i != 0, "Route Error"
            break
        amount = self._token2Token(_uToken, uToken, feeLevel, amount, block.timestamp)
        _uToken = uToken
    self._deposit(_uToken, amount)
    assert old_amount * minPrice <= amount * 10 ** 18, "High Slippage"
    self.u_token = _uToken
    self.a_token = self.get_atoken(_uToken)

@external
def harvest(minPrice: uint256):
    assert self.adjuster[msg.sender], "Not adjuster"
    _response: Bytes[32] = raw_call(
        INCENTIVES_CONTROLLER,
        concat(
            CR_MID,
            convert(96, bytes32),
            convert(MAX_UINT256, bytes32),
            convert(self, bytes32),
            convert(0, bytes32)
        ),
        max_outsize=32
    )
    claimed: uint256 = convert(_response, uint256)
    amount: uint256 = self._token2Token(stkAAVE, AAVE, 500, claimed, block.timestamp)
    amount = self._token2Token(AAVE, WETH, 3000, amount, block.timestamp)
    _uToken: address = self.u_token
    amount = self._token2Token(WETH, _uToken, 3000, amount, block.timestamp)
    assert claimed * minPrice <= amount * 10 ** 18, "High Slippage"
    self._deposit(_uToken, ERC20(_uToken).balanceOf(self))

@external
def transferOwnership(_owner: address):
    assert msg.sender == self.owner
    assert _owner != ZERO_ADDRESS
    self.owner = _owner

@external
def setValidator(_validator: address, _value: bool):
    assert msg.sender == self.owner
    self.validator[_validator] = _value

@external
def setAdjuster(_adjuster: address, _value: bool):
    assert msg.sender == self.owner
    self.adjuster[_adjuster] = _value

@external
def setLendingPool(_lendingPool: address):
    assert msg.sender == self.owner
    self.lendingPool = _lendingPool

@external
def setServiceFee(_serviceFee: uint256):
    assert msg.sender == self.owner
    self.serviceFee = _serviceFee