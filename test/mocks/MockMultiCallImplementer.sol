// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MulticallV2} from "../../src/shared/utils/MulticallV2.sol";

contract MockMultiCallImplementer is MulticallV2 {
    uint256 public value;

    mapping(uint256 => uint256) public valueMap;

    event ValueSet(uint256 value);

    error ValueNotSet();
    error IllegalValue(uint256 value);

    function setValue(uint256 _value) public {
        value = _value;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function getValueMap(uint256 _key) public view returns (uint256) {
        return valueMap[_key];
    }

    function setValueAndEmit(uint256 _value) public {
        value = _value;
        emit ValueSet(_value);
    }

    function setValueMapAndEmit(uint256 _key, uint256 _value) public returns (uint256) {
        if (_value == 69) revert IllegalValue(_value);
        valueMap[_key] = _value;
        emit ValueSet(_value);
        return _value;
    }

    function setValueAndEmitAndReturn(uint256 _value) public returns (uint256) {
        value = _value;
        emit ValueSet(_value);
        return _value;
    }

    function getValueOrError() public view returns (uint256) {
        if (value == 0) revert ValueNotSet();
        return value;
    }

    function batchSetValuesAndEmit(uint256[] calldata _values) public returns (bytes[] memory returnData) {
        bytes[] memory callData = new bytes[](_values.length);

        for (uint256 i = 0; i < _values.length; i++) {
            callData[i] = abi.encodeWithSelector(0xf6b9b7a0, i, _values[i]);
        }

        returnData = _multicallInternal(callData);
        return returnData;
    }
}
