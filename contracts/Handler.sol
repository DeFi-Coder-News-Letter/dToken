pragma solidity 0.5.12;

import './library/ERC20SafeTransfer.sol';
import './library/Ownable.sol';
import './library/SafeMath.sol';


contract Handler is Ownable, ERC20SafeTransfer {

    using SafeMath for uint;

    address targetAddr;  // market address
    address dToken;      // dToken address

    /**
     * @dev Throws if called by any account other than the dToken.
     */
    modifier onlyDToken() {
        require(msg.sender == dToken, "non-dToken");
        _;
    }

    constructor (address _targetAddr, address _dToken) public {
        targetAddr = _targetAddr;
        dToken = _dToken;
    }

    /**
     * @dev Take out token, but only for owenr.
     * @param _token Token address to take out.
     * @param _recipient Account address to receive token.
     * @param _amount Token amount to take out.
     */
    function takeOut(address _token, address _recipient, uint _amount) external onlyOwner {
        require(doTransferOut(_token, _recipient, _amount), 'takeOut: transfer token out of contract failed.');
    }

    /**
     * @dev This token `_token` approves to market and dToken contract.
     * @param _token Token address to approve.
     */
    function approve(address _token) public {

        if (IERC20(_token).allowance(address(this), targetAddr) != uint(-1))
            require(doApprove(_token, targetAddr, uint(-1)), "approve: Handler contract approve target failed.");

        if (IERC20(_token).allowance(address(this), dToken) != uint(-1))
            require(doApprove(_token, dToken, uint(-1)), "approve: Handler contract approve dToken failed.");
    }

    /**
     * @dev Supply token to market, but only for dToken contract.
     * @param _token Token to deposit.
     * @return True is success, false is failure.
     */
    function deposit(address _token) external onlyDToken returns (bool) {
        return true;
    }

    /**
     * @dev Withdraw token from market, but only for dToken contract.
     * @param _token Token to withdraw.
     * @param _amount Token amount to withdraw.
     * @return Actually withdraw token amount.
     */
    function withdraw(address _token, uint _amount) external onlyDToken returns (uint){
        return _amount;
    }


    /**
     * @dev Supply balance with any accumulated interest for `_token` belonging to `handler`
     * @param _token Token to get balance.
     */
    function getBalance(address _token) public view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @dev The maximum withdrawable amount of token `_token` in the market.
     * @param _token Token to get balance.
     */
    function getLiquidity(address _token) public view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }
}
