pragma solidity 0.5.12;

import './interface/IDispatcher.sol';
import './interface/IHandler.sol';
import './library/ERC20SafeTransfer.sol';
import './library/SafeMath.sol';
import './library/Ownable.sol';
import './library/ERC20.sol';

contract DToken is ERC20SafeTransfer, ERC20, Ownable  {
    using SafeMath for uint;
    // --- Data ---
    bool private initialized;           // Flag of initialize data

    uint public exchangeRate;           // The rate accumulator
    uint public lastTriggerTime;        // The last recorded time
    uint public bufferExchangeRate;     // The cache rate accumulator
    uint public bufferLastTriggerTime;  // The cache recorded time
    uint public samplingInterval;       // Minimum time interval for exchange rate changes

    uint public originationFee;         // Trade fee

    address public dispatcher;
    address public token;

    uint constant BASE = 10 ** 18;

    // --- ERC20 Data ---
    string  public name;
    string  public symbol;
    uint8   public decimals;
    uint256 public totalToken;

    event NewDispatcher(address Dispatcher, address oldDispatcher);
    event NewOriginationFee(uint oldOriginationFeeMantissa, uint newOriginationFeeMantissa);
    event NewSamplingInterval(uint oldSamplingInterval, uint newSamplingInterval);

    /**
     * The constructor is used here to ensure that the implementation
     * contract is initialized. An uncontrolled implementation
     * contract might lead to misleading state
     * for users who accidentally interact with it.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _token,
        address _dispatcher,
        uint _originationFee
    ) public {
        initialize(_name, _symbol, _decimals, _token, _dispatcher, _originationFee);
    }

    // --- Init ---
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _token,
        address _dispatcher,
        uint _originationFee
    ) public {
        require(!initialized, "initialize: already initialized.");
        require(_originationFee < BASE / 10, "initialize: fee should be less than ten percent.");
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        token = _token;
        dispatcher = _dispatcher;
        originationFee = _originationFee;
        exchangeRate = BASE;
        bufferExchangeRate = BASE;
        lastTriggerTime = now;
        bufferLastTriggerTime = now;
        initialized = true;
        samplingInterval = 60;

        emit NewDispatcher(_dispatcher, address(0));
        emit NewOriginationFee(0, _originationFee);
        emit NewSamplingInterval(0, 60);
    }

    /**
     * @dev Manager function to set a new dispatcher contract address.
     * @param _newDispatcher New dispatcher contract address.
     * @return bool true=success, otherwise a failure.
     */
    function updateDispatcher(address _newDispatcher) external onlyManager returns (bool) {
        address _oldDispatcher = dispatcher;
        require(_newDispatcher != _oldDispatcher, "updateDispatcher: same dispatcher address.");
        dispatcher = _newDispatcher;
        emit NewDispatcher(_newDispatcher, _oldDispatcher);

        return true;
    }


    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x.mul(y) / BASE;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = x.mul(BASE) / y;
    }

    function rdivup(uint x, uint y) internal pure returns (uint z) {
        z = x.mul(BASE).add(y.sub(1)) / y;
    }

    /**
     * @dev After the operation, check whether the remaining token balance is valid or not.
     * @param _handlers All support `handler` address.
     * @param _token Token address to check.
     */
    function checkTotalToken(address[] memory _handlers, address _token) internal view {
        // Accumulate each handler balance.
        uint _tokenTotal = 0;
        for (uint i = 0; i < _handlers.length; i++)
            _tokenTotal = _tokenTotal.add(IHandler(_handlers[i]).getBalance(_token));

        // The accumulated amount can not be greater than the total deposit amount of handlers.
        require(totalToken <= _tokenTotal, "checkTotalToken: invalid token amount");
    }

    /**
     * @dev Update the exchange rate to ensure current exchange rate is not expired.
     * @param _exchangeRate Current exchange rate.
     */
    function snapshot(uint _exchangeRate) internal {
        // If the exchange rate has expired, then update it.
        if (now - lastTriggerTime > samplingInterval) {
            bufferExchangeRate = exchangeRate;
            bufferLastTriggerTime = lastTriggerTime;
            exchangeRate = _exchangeRate;
            lastTriggerTime = now;
        }
    }

    /**
     * @dev Deposit token to earn savings, but only when the contract is not paused.
     * @param _dst Account who will get savings.
     * @param _pie Amount to deposit, scaled by 1e18.
     */
    function mint(address _dst, uint _pie) public {
        // Get deposit strategy base on the deposit amount `_pie`.
        (address[] memory _handlers, uint[] memory _amount) = IDispatcher(dispatcher).getDepositStrategy(_pie);

        address _token = token;
        // Get current exchange rate.
        uint _exchangeRate = getExchangeRateByHandler(_handlers, _token);

        for (uint i = 0; i < _handlers.length; i++) {
            // If deposit amount is 0 by this handler, then pass.
            if (_amount[i] == 0)
                continue;
            // Transfer the calculated token amount from `msg.sender` to the `handler`.
            require(doTransferFrom(_token, msg.sender, _handlers[i], _amount[i]), "mint: transferFrom token failed");
            // The `handler` deposit obtained token to corresponding market to earn savings.
            require(IHandler(_handlers[i]).deposit(_token), "mint: handler deposit failed");
        }

        // Calculate amount of the dToken based on current exchange rate.
        uint _wad = rdivup(_pie, _exchangeRate);
        _balances[_dst] = _balances[_dst].add(_wad);
        _totalSupply = _totalSupply.add(_wad);
        // Update memory exchange rate.
        snapshot(_exchangeRate);

        // Increase total amount of the dToken.
        totalToken = totalToken.add(_pie);

        // After operation, check if the token change is reasonable.
        checkTotalToken(_handlers, _token);
        emit Transfer(address(0), _dst, _wad);
    }

    /**
     * @dev Withdraw to get token according to input dToken amount,
     *      but only when the contract is not paused.
     * @param _src Account who will spend dToken.
     * @param _wad Amount to burn dToken, scaled by 1e18.
     */
    function burn(address _src, uint _wad) public {
        // Get current exchange rate.
        uint _exchangeRate = getExchangeRate();
        require(_balances[_src] >= _wad, "burn: insufficient balance");
        if (_src != msg.sender && _allowed[_src][msg.sender] != uint(-1)) {
            require(_allowed[_src][msg.sender] >= _wad, "burn: insufficient _allowed");
            _allowed[_src][msg.sender] = _allowed[_src][msg.sender].sub(_wad);
        }
        _balances[_src] = _balances[_src].sub(_wad);
        _totalSupply = _totalSupply.sub(_wad);

        // Calculate amount of the token based on current exchange rate.
        uint _pie = rmul(_wad, _exchangeRate);
        address _token = token;
        uint _totalAmount;
        uint _userAmount;

        // Get `_token` best withdraw strategy base on the withdraw amount `_pie`.
        (address[] memory _handlers, uint[] memory _amount) = IDispatcher(dispatcher).getWithdrawStrategy(_token, _pie);
        for (uint i = 0; i < _handlers.length; i++) {
            if (_amount[i] == 0)
                continue;

            // The `handler` withdraw calculated amount from the market.
            _totalAmount = IHandler(_handlers[i]).withdraw(_token, _amount[i]);
            require(_totalAmount > 0, "burn: handler withdraw failed");

            // After subtracting the fee, the user finally can get quantity.
            _userAmount = rmul(_totalAmount, BASE.sub(originationFee));
            // Transfer the calculated token amount from the `handler` to the receiver `_src`.
            if (_userAmount > 0)
                require(doTransferFrom(_token, _handlers[i], msg.sender, _userAmount), "burn: transfer to user failed");

            // Transfer the token trade fee from the `handler` to the `dToken`.
            require(doTransferFrom(_token, _handlers[i], address(this), _totalAmount.sub(_userAmount)),
                    "burn: transfer fee failed");

        }

        // Update cache exchange rate.
        snapshot(_exchangeRate);

        // Decrease total amount of the dToken.
        totalToken = totalToken > _pie ? totalToken.sub(_pie) : 0;
        // After operation, check if the token change is reasonable.
        checkTotalToken(_handlers, _token);
        emit Transfer(_src, address(0), _wad);
    }

    /**
     * @dev Get the current list of the `handlers`.
     */
    function getHandler() public view returns (address[] memory) {
        (address[] memory _handlers,) = IDispatcher(dispatcher).getHandler();
        return _handlers;
    }

    /**
     * @dev Current newest exchange rate, scaled by 1e18.
     */
    function getExchangeRate() public view returns (uint) {
        address[] memory _handlers = getHandler();
        return getExchangeRateByHandler(_handlers, token);
    }

    /**
     * @dev According to `_handlers` and token amount `_token` to calculate the exchange rate.
     * @param _handlers The list of `_handlers`.
     * @param _token Token address.
     * @return Current exchange rate between token and dToken.
     */
    function getExchangeRateByHandler(address[] memory _handlers, address _token) public view returns (uint) {
        uint _tokenTotal = 0;
        for (uint i = 0; i < _handlers.length; i++)
            _tokenTotal = _tokenTotal.add(IHandler(_handlers[i]).getBalance(_token));

        return _totalSupply == 0 || _tokenTotal == 0 ? exchangeRate : rdiv(_tokenTotal, _totalSupply);
    }
}
