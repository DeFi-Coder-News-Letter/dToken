pragma solidity 0.5.12;

import './interface/IHandler.sol';
import './library/Ownable.sol';
import './library/SafeMath.sol';

contract Dispatcher is Ownable {

    using SafeMath for uint;

    /**
     * @dev List all handler contract address.
     */
    address[] public handlers;

	/**
     * @dev Deposit ratio of each handler contract.
     *      Notice: the sum of all deposit ratio should be 1000.
     */
    mapping(address => uint) public propotions;

    /**
     * @dev map: handlerAddress -> true/false,
     *      Whether the handler has been added or not.
     */
    mapping(address => bool) public handlerActive;

    /**
     * @dev Set original handler contract and its depoist ratio.
     *      Notice: the sum of all deposit ratio should be 1000.
     * @param _handlers The original support handler contract.
     * @param _propotions The original depoist ratio of support handler.
     */
    constructor (address[] memory _handlers, uint[] memory _propotions) public {
        setHandler(_handlers, _propotions);
    }

    /**
     * @dev Set config for `handlers` and corresponding `propotions`.
     * @param _handlers The support handler contract.
     * @param _propotions Depoist ratio of support handler.
     */
    function setHandler(address[] memory _handlers, uint[] memory _propotions) private {
        // The length of `_handlers` must be equal to the length of `_propotions`.
        require(_handlers.length == _propotions.length, "setHandler: array parameters mismatch");
        uint _sum = 0;
        for (uint i = 0; i < _handlers.length; i++) {
            require(_handlers[i] != address(0), "setHandler: handlerAddr contract address invalid");
            require(_propotions[i] > 0, "setHandler: propotions must greater than 0");
            _sum = _sum.add(_propotions[i]);

            handlers.push(_handlers[i]);
            propotions[_handlers[i]] = _propotions[i];
            handlerActive[_handlers[i]] = true;
        }
        // If the `handlers` is not empty, the sum of `propotions` should be 1000.
        if (handlers.length > 0)
            require(_sum == 1000, "the sum of propotions must be 1000");
    }

    /**
     * @dev Update `propotions` of the `handlers`.
     * @param _handlers List of the `handlers` to update.
     * @param _propotions List of the `promotions` corresponding to `handlers` to update.
     */
    function updatePropotion(address[] memory _handlers, uint[] memory _propotions) public onlyManager {
        // The length of `_handlers` must be equal to the length of `_propotions`
        require(_handlers.length == _propotions.length && handlers.length == _propotions.length,
                "updatePropotion: array parameters mismatch");

        uint _sum = 0;
        for(uint i = 0; i < _propotions.length; i++){
            require(handlerActive[_handlers[i]], "updatePropotion: the handler contract address does not exist");
            _sum = _sum.add(_propotions[i]);

            propotions[_handlers[i]] = _propotions[i];
        }

        // The sum of `propotions` should be 1000.
        require(_sum == 1000, "the sum of propotions must be 1000");
    }

	/**
     * @dev Add new handler.
     *      Notice: the corresponding ratio of the new handler is 0.
     * @param _handlers List of the new handlers to add.
     */
    function addHandler(address[] memory _handlers) public onlyManager {

        for(uint i = 0; i < _handlers.length; i++){
            require(!handlerActive[_handlers[i]], "addHandler: handler contract address already exists");
            require(_handlers[i] != address(0), "addHandler: handler contract address invalid");

            handlers.push(_handlers[i]);
            propotions[_handlers[i]] = 0;
            handlerActive[_handlers[i]] = true;
        }
    }

    /**
     * @dev Query the current handler and the corresponding ratio.
     * @return Return two arrays, one is the current handler,
     *         and the other is the corresponding ratio.
     */
    function getHandler() external view returns (address[] memory, uint[] memory) {
        address[] memory _handlers = handlers;
        uint[] memory _propotions = new uint[](_handlers.length);
        for (uint i = 0; i < _propotions.length; i++)
            _propotions[i] = propotions[_handlers[i]];

        return (_handlers, _propotions);
    }

    /**
     * @dev According to the `propotion` of the `handlers`, calculate corresponding deposit amount.
     * @param _amount The amount to deposit.
     * @return Return two arrays, one is the current handler,
     *         and the other is the corresponding deposit amount.
     */
    function getDepositStrategy(uint _amount) external view returns (address[] memory, uint[] memory) {
        address[] memory _handlers = handlers;

        uint[] memory _amounts = new uint[](_handlers.length);

        uint _sum = 0;
        uint _lastIndex = _amounts.length.sub(1);
        for(uint i = 0; ; i++){
            // Calculate deposit amount according to the `propotion` of the `handlers`,
            // and the last handler gets the remaining quantity directly without calculating.
            if (i == _lastIndex) {
                _amounts[i] = _amount.sub(_sum);
                break;
            }

            _amounts[i] = _amount.mul(propotions[_handlers[i]]) / 1000;
            _sum = _sum.add(_amounts[i]);
        }

        return (_handlers, _amounts);
    }

    /**
     * @dev According to new `handlers` which are sorted in order from small to large base on the APR
     *      of corresponding asset, provide a best strategy when withdraw asset.
     * @param _token The asset to withdraw.
     * @param _amount The amount to withdraw including exchange fees between tokens.
     * @return Return two arrays, one is the current handler,
     *         and the other is the corresponding withdraw amount.
     */
    function getWithdrawStrategy(address _token, uint _amount) external view returns (address[] memory, uint[] memory) {

        address[] memory _handlers = handlers;

        uint[] memory _amounts = new uint[](_handlers.length);

        uint _balance;
        uint _sum = _amount;
        uint _lastIndex = _amounts.length.sub(1);
        for (uint i = 0; ; i++) {
            // The minimum amount can be withdrew from corresponding market.
            _balance = IHandler(_handlers[i]).getLiquidity(_token);
            if (_balance > _sum || i == _lastIndex){
                _amounts[i] = _sum;
                break;
            }

            _amounts[i] = _balance;
            _sum = _sum.sub(_balance);
        }

        return (_handlers, _amounts);
    }
}
