pragma solidity 0.4.24;

import "../BasicForeignBridge.sol";
import "../ERC20Bridge.sol";

contract ForeignBridgeErcToNative is BasicForeignBridge, ERC20Bridge {
    event RelayedMessage(address recipient, uint256 value, bytes32 transactionHash);

    function initialize(
        address _validatorContract,
        address _erc20token,
        uint256 _requiredBlockConfirmations,
        uint256 _gasPrice,
        uint256[] _limitsArray, //[ 0 = _maxPerTx, 1 = _homeDailyLimit, 2 = _homeMaxPerTx, 3 = _homeMinPerTx ]
        address _owner,
        uint256 _decimalShift
    ) external returns (bool) {
        require(
            _limitsArray[3] > 0 && // _homeMinPerTx > 0
                _limitsArray[2] > _limitsArray[3] && // _homeMaxPerTx > _homeMinPerTx
                _limitsArray[2] < _limitsArray[1] // _homeMaxPerTx < _homeDailyLimit
        );

        uintStorage[MAX_PER_TX] = _limitsArray[0];
        uintStorage[EXECUTION_DAILY_LIMIT] = _limitsArray[1];
        uintStorage[EXECUTION_MAX_PER_TX] = _limitsArray[2];
        uintStorage[EXECUTION_MIN_PER_TX] = _limitsArray[3];

        emit ExecutionDailyLimitChanged(_limitsArray[1]);

        return
            _initialize(_validatorContract, _erc20token, _requiredBlockConfirmations, _gasPrice, _owner, _decimalShift);
    }

    function _initialize(
        address _validatorContract,
        address _erc20token,
        uint256 _requiredBlockConfirmations,
        uint256 _gasPrice,
        address _owner,
        uint256 _decimalShift
    ) internal returns (bool) {
        require(!isInitialized());
        require(AddressUtils.isContract(_validatorContract));
        require(_requiredBlockConfirmations != 0);
        require(_gasPrice > 0);
        require(_owner != address(0));

        addressStorage[VALIDATOR_CONTRACT] = _validatorContract;
        setErc20token(_erc20token);
        uintStorage[DEPLOYED_AT_BLOCK] = block.number;
        uintStorage[REQUIRED_BLOCK_CONFIRMATIONS] = _requiredBlockConfirmations;
        uintStorage[GAS_PRICE] = _gasPrice;
        uintStorage[DECIMAL_SHIFT] = _decimalShift;
        setOwner(_owner);
        setInitialize();

        emit RequiredBlockConfirmationChanged(_requiredBlockConfirmations);
        emit GasPriceChanged(_gasPrice);

        return isInitialized();
    }

    function getBridgeMode() external pure returns (bytes4 _data) {
        return 0x18762d46; // bytes4(keccak256(abi.encodePacked("erc-to-native-core")))
    }

    function claimTokens(address _token, address _to) public {
        require(_token != address(erc20token()));
        super.claimTokens(_token, _to);
    }

    function onExecuteMessage(
        address _recipient,
        uint256 _amount,
        bytes32 /*_txHash*/
    ) internal returns (bool) {
        setTotalExecutedPerDay(getCurrentDay(), totalExecutedPerDay(getCurrentDay()).add(_amount));
        uint256 amount = _amount.div(10**decimalShift());
        return erc20token().transfer(_recipient, amount);
    }

    function onFailedMessage(address, uint256, bytes32) internal {
        revert();
    }
}
