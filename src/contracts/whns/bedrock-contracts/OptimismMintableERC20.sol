// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ILegacyMintableERC20, IOptimismMintableERC20} from "./IOptimismMintableERC20.sol";
import {ISemver} from "./ISemver.sol";

/// @title OptimismMintableERC20
/// @notice OptimismMintableERC20 is a standard extension of the base ERC20 token contract designed
///         to allow the StandardBridge contracts to mint and burn tokens. This makes it possible to
///         use an OptimismMintablERC20 as the L2 representation of an L1 token, or vice-versa.
///         Designed to be backwards compatible with the older StandardL2ERC20 token which was only
///         meant for use on L2.
contract OptimismMintableERC20 is IOptimismMintableERC20, ILegacyMintableERC20, ERC20, ISemver {
    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this network.
    address public immutable BRIDGE;

    /// @notice Decimals of the token
    uint8 private immutable DECIMALS;

    error OnlyBridge();

    /// @notice A modifier that only allows the bridge to call
    modifier onlyBridge() {
        if (msg.sender != BRIDGE) {
            revert OnlyBridge();
        }
        _;
    }

    /// @notice Semantic version.
    /// @custom:semver 1.3.0
    string public constant version = "1.3.0";

    /// @param _bridge      Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    /// @param _name        ERC20 name.
    /// @param _symbol      ERC20 symbol.
    constructor(address _bridge, address _remoteToken, string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol)
    {
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        DECIMALS = _decimals;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount)
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _mint(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function burn(address _from, uint256 _amount)
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _burn(_from, _amount);
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the legacy L2StandardERC20.
        bytes4 iface2 = type(ILegacyMintableERC20).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2 || _interfaceId == iface3;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the remote token. Use REMOTE_TOKEN going forward.
    function l1Token() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the bridge. Use BRIDGE going forward.
    function l2Bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @dev Returns the number of decimals used to get its user representation.
    /// For example, if `decimals` equals `2`, a balance of `505` tokens should
    /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
    /// NOTE: This information is only used for _display_ purposes: it in
    /// no way affects any of the arithmetic of the contract, including
    /// {IERC20-balanceOf} and {IERC20-transfer}.
    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }
}
