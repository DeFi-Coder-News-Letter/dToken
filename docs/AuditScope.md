# dForce Yield Token

## Audit Scope

1. dToken.sol
    - function mint(address _dst, uint _pie) public
    - function burn(address _src, uint _wad) public

2. Dispatcher.sol
    - function getDepositStrategy(uint _amount) external view
    - function getWithdrawStrategy(address _token, uint _amount) external view
