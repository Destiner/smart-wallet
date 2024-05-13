// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {LibClone} from "solady/utils/LibClone.sol";

import {CoinbaseSmartWallet} from "../../src/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "../../src/CoinbaseSmartWalletFactory.sol";
import {MultiOwnable} from "../../src/MultiOwnable.sol";

import {LibMultiOwnable} from "../utils/LibMultiOwnable.sol";

contract CoinbaseSmartWalletFactoryTest is Test {
    CoinbaseSmartWallet private sw;
    CoinbaseSmartWalletFactory private sut;

    function setUp() public {
        sw = new CoinbaseSmartWallet({keyStore_: address(0), stateVerifier_: address(0)});
        sut = new CoinbaseSmartWalletFactory(address(sw));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                            MODIFIERS                                           //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    modifier witkKeyCountNotZero(uint8 keyCount) {
        vm.assume(keyCount > 0);
        _;
    }

    modifier withAccountDeployed(uint8 keyCount, uint256 nonce) {
        address account = sut.getAddress({ksKeyAndTypes: LibMultiOwnable.generateKeyAndTypes(keyCount), nonce: nonce});
        vm.etch({target: account, newRuntimeBytecode: "Some bytecode"});
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                             TESTS                                              //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @custom:test-section createAccount

    function test_createAccount_reverts_whenNoksKeyAndTypesAreProvided(uint256 nonce) external {
        MultiOwnable.KeyAndType[] memory ksKeyAndTypes;

        vm.expectRevert(CoinbaseSmartWalletFactory.KeyRequired.selector);
        sut.createAccount({ksKeyAndTypes: ksKeyAndTypes, nonce: nonce});
    }

    function test_createAccount_deploysTheAccount_whenNotAlreadyDeployed(uint8 keyCount, uint256 nonce)
        external
        witkKeyCountNotZero(keyCount)
    {
        address account =
            address(sut.createAccount({ksKeyAndTypes: LibMultiOwnable.generateKeyAndTypes(keyCount), nonce: nonce}));
        assertTrue(account != address(0));
        assertGt(account.code.length, 0);
    }

    function test_createAccount_initializesTheAccount_whenNotAlreadyDeployed(uint8 keyCount, uint256 nonce)
        external
        witkKeyCountNotZero(keyCount)
    {
        MultiOwnable.KeyAndType[] memory ksKeyAndTypes = LibMultiOwnable.generateKeyAndTypes(keyCount);

        address expectedAccount = _create2Address({ksKeyAndTypes: ksKeyAndTypes, nonce: nonce});
        vm.expectCall({callee: expectedAccount, data: abi.encodeCall(CoinbaseSmartWallet.initialize, (ksKeyAndTypes))});
        sut.createAccount({ksKeyAndTypes: ksKeyAndTypes, nonce: nonce});
    }

    function test_createAccount_returnsTheAccountAddress_whenAlreadyDeployed(uint8 keyCount, uint256 nonce)
        external
        witkKeyCountNotZero(keyCount)
        withAccountDeployed(keyCount, nonce)
    {
        address account =
            address(sut.createAccount({ksKeyAndTypes: LibMultiOwnable.generateKeyAndTypes(keyCount), nonce: nonce}));
        assertTrue(account != address(0));
        assertGt(account.code.length, 0);
    }

    /// @custom:test-section getAddress

    function test_getAddress_returnsTheAccountCounterfactualAddress(uint8 keyCount, uint256 nonce) external {
        MultiOwnable.KeyAndType[] memory ksKeyAndTypes = LibMultiOwnable.generateKeyAndTypes(keyCount);

        address expectedAccountAddress = _create2Address({ksKeyAndTypes: ksKeyAndTypes, nonce: nonce});
        address accountAddress = sut.getAddress({ksKeyAndTypes: ksKeyAndTypes, nonce: nonce});

        assertEq(accountAddress, expectedAccountAddress);
    }

    /// @custom:test-section initCodeHash

    function test_initCodeHash_returnsTheInitCodeHash() external {
        assertEq(sut.initCodeHash(), LibClone.initCodeHashERC1967(address(sw)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                         TESTS HELPERS                                          //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    function _create2Address(MultiOwnable.KeyAndType[] memory ksKeyAndTypes, uint256 nonce)
        private
        view
        returns (address)
    {
        return vm.computeCreate2Address({
            salt: _getSalt(ksKeyAndTypes, nonce),
            initCodeHash: LibClone.initCodeHashERC1967(address(sw)),
            deployer: address(sut)
        });
    }

    function _getSalt(MultiOwnable.KeyAndType[] memory ksKeyAndTypes, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(ksKeyAndTypes, nonce));
    }
}