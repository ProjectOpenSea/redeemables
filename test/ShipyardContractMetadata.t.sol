// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IERC721Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/interfaces/IERC1155MetadataURI.sol";
import {IERC2981} from "openzeppelin-contracts/contracts/interfaces/IERC2981.sol";
import {ERC721ShipyardContractMetadata} from "../src/lib/ERC721ShipyardContractMetadata.sol";
import {ERC1155ShipyardContractMetadata} from "../src/lib/ERC1155ShipyardContractMetadata.sol";
import {IShipyardContractMetadata} from "../src/interfaces/IShipyardContractMetadata.sol";

contract ERC721ShipyardContractMetadataOwnerMintable is ERC721ShipyardContractMetadata {
    constructor(string memory name_, string memory symbol_) ERC721ShipyardContractMetadata(name_, symbol_) {}

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }
}

contract ERC1155ShipyardContractMetadataOwnerMintable is ERC1155ShipyardContractMetadata {
    constructor(string memory name_, string memory symbol_) ERC1155ShipyardContractMetadata(name_, symbol_) {}

    function mint(address to, uint256 tokenId, uint256 amount) external onlyOwner {
        _mint(to, tokenId, amount, "");
    }
}

contract TestShipyardContractMetadata is BaseRedeemablesTest {
    ERC721ShipyardContractMetadataOwnerMintable token721;
    ERC1155ShipyardContractMetadataOwnerMintable token1155;
    address[] tokens;

    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated(string uri);
    event ProvenanceHashUpdated(bytes32 oldProvenanceHash, bytes32 newProvenanceHash);
    event RoyaltyInfoUpdated(address receiver, uint256 basisPoints);

    function setUp() public override {
        token721 = new ERC721ShipyardContractMetadataOwnerMintable("Test", "TST");
        token1155 = new ERC1155ShipyardContractMetadataOwnerMintable("Test", "TST");
        tokens = new address[](2);
        tokens[0] = address(token721);
        tokens[1] = address(token1155);
    }

    function testNameAndSymbol() external {
        for (uint256 i; i < tokens.length; i++) {
            this.nameAndSymbol(IShipyardContractMetadata(tokens[i]));
        }
    }

    function nameAndSymbol(IShipyardContractMetadata token) external {
        assertEq(token.name(), "Test");
        assertEq(token.symbol(), "TST");
    }

    function testOwner() external {
        for (uint256 i; i < tokens.length; i++) {
            this.owner(IShipyardContractMetadata(tokens[i]));
        }
    }

    function owner(IShipyardContractMetadata token) external {
        assertEq(Ownable(address(token)).owner(), address(this));
    }

    function testBaseURI() external {
        for (uint256 i; i < tokens.length; i++) {
            this.baseURI(IShipyardContractMetadata(tokens[i]));
        }
    }

    function baseURI(IShipyardContractMetadata token) external {
        uint256 tokenId = 1;
        _mintToken(address(token), tokenId);

        if (_isERC721(address(token))) {
            assertEq(IERC721Metadata(address(token)).tokenURI(tokenId), "");
        } else {
            // token is 1155
            assertEq(IERC1155MetadataURI(address(token)).uri(tokenId), "");
        }

        assertEq(token.baseURI(), "");
        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(0, type(uint256).max);
        token.setBaseURI("https://example.com/");
        assertEq(token.baseURI(), "https://example.com/");

        if (_isERC721(address(token))) {
            assertEq(IERC721Metadata(address(token)).tokenURI(tokenId), string.concat("https://example.com/", "1"));

            // For ERC721, without the slash shouldn't append tokenId,
            // for e.g. prereveal states of when all tokens have the same metadata.
            // For ERC1155, {id} substitution defined in spec can be used.
            token.setBaseURI("https://example.com");
            assertEq(token.baseURI(), "https://example.com");
            assertEq(IERC721Metadata(address(token)).tokenURI(tokenId), "https://example.com");
        } else {
            // token is 1155
            assertEq(IERC1155MetadataURI(address(token)).uri(tokenId), string.concat("https://example.com/"));
        }
    }

    function testContractURI() external {
        for (uint256 i; i < tokens.length; i++) {
            this.contractURI(IShipyardContractMetadata(tokens[i]));
        }
    }

    function contractURI(IShipyardContractMetadata token) external {
        assertEq(token.contractURI(), "");
        vm.expectEmit(true, true, true, true);
        emit ContractURIUpdated("https://example.com/");
        token.setContractURI("https://example.com/");
        assertEq(token.contractURI(), "https://example.com/");
    }

    function testSetProvenanceHash() external {
        for (uint256 i; i < tokens.length; i++) {
            this.setProvenanceHash(IShipyardContractMetadata(tokens[i]));
        }
    }

    function setProvenanceHash(IShipyardContractMetadata token) external {
        assertEq(token.provenanceHash(), "");
        vm.expectEmit(true, true, true, true);
        emit ProvenanceHashUpdated(bytes32(0), bytes32(uint256(1234)));
        token.setProvenanceHash(bytes32(uint256(1234)));
        assertEq(token.provenanceHash(), bytes32(uint256(1234)));

        // Setting the provenance hash again should revert.
        vm.expectRevert(IShipyardContractMetadata.ProvenanceHashCannotBeSetAfterAlreadyBeingSet.selector);
        token.setProvenanceHash(bytes32(uint256(5678)));
    }

    function testSetDefaultRoyalty() external {
        for (uint256 i; i < tokens.length; i++) {
            this.setDefaultRoyalty(IShipyardContractMetadata(tokens[i]));
        }
    }

    function setDefaultRoyalty(IShipyardContractMetadata token) external {
        address greg = makeAddr("greg");
        vm.expectEmit(true, true, true, true);
        emit RoyaltyInfoUpdated(greg, 9_000);
        token.setDefaultRoyalty(greg, 9_000);
        (address receiver, uint256 amount) = IERC2981(address(token)).royaltyInfo(0, 100);
        assertEq(receiver, greg);
        assertEq(amount, 100 * 9_000 / 10_000);
    }
}
