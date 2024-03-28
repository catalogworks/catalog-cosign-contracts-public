// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("NFT(address artist,address nftContract,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 private constant NFT_TYPEHASH = 0x8bfe81a66a2ac3d07208cde163232feba15418a2b31fd3fc43ac04e8d15b4918;

    struct NFT {
        address artist;
        address nftContract;
        uint256 tokenId;
        uint256 nonce;
        uint256 deadline;
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of an NFT struct
    function getStructHashNFT(NFT memory _nft) internal pure returns (bytes32) {
        return
            keccak256(abi.encode(NFT_TYPEHASH, _nft.artist, _nft.nftContract, _nft.tokenId, _nft.nonce, _nft.deadline));
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHashNFT(NFT memory _nft) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHashNFT(_nft)));
    }

    // computes the hash of a permit
    function getStructHashPermit(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHashPermit(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHashPermit(_permit)));
    }
}
