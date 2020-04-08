pragma solidity 0.5.12;

interface IDispatcher {
    function getHandler() external view returns (address[] memory, uint[] memory);
	function getDepositStrategy(uint _amount) external view returns (address[] memory, uint[] memory);
	function getWithdrawStrategy(address _token, uint _amount) external view returns (address[] memory, uint[] memory);
	function getRedeemStrategy(address _token, uint _amount) external view returns (address[] memory, uint[] memory);
	function getRealAmount(uint _pie) external view returns (uint);
}
