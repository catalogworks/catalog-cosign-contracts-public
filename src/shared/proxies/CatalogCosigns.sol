// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │     .oooooo.                 .             oooo                          │
 * │    d8P'  `Y8b              .o8             `888                          │
 * │   888           .oooo.   .o888oo  .oooo.    888   .ooooo.   .oooooooo    │
 * │   888          `P  )88b    888   `P  )88b   888  d88' `88b 888' `88b     │
 * │   888           .oP"888    888    .oP"888   888  888   888 888   888     │
 * │   `88b    ooo  d8(  888    888 . d8(  888   888  888   888 `88bod8P'     │
 * │    `Y8bood8P'  `Y888""8o   "888" `Y888""8o o888o `Y8bod8P' `8oooooo.     │
 * │                                                            d"     YD     │
 * │                                                            "Y88888P'     │
 * │                                                                          │
 * │    .oooooo.                       o8o                                    │
 * │   d8P'  `Y8b                      `"'                                    │
 * │  888           .ooooo.   .oooo.o oooo   .oooooooo ooo. .oo.    .oooo.o   │
 * │  888          d88' `88b d88(  "8 `888  888' `88b  `888P"Y88b  d88(  "8   │
 * │  888          888   888 `"Y88b.   888  888   888   888   888  `"Y88b.    │
 * │  `88b    ooo  888   888 o.  )88b  888  `88bod8P'   888   888  o.  )88b   │
 * │   `Y8bood8P'  `Y8bod8P' 8""888P' o888o `8oooooo.  o888o o888o 8""888P'   │
 * │                                        d"     YD                         │
 * │                                        "Y88888P'                         │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                   ┌────────────────────────────────┐                     │
 * │                   │             PROXY              │                     │
 * │                   └────────────────────────────────┘                     │
 * │                                                                          │
 * │                                                                          │
 * └──────────────────────────────────────────────────────────────────────────┘
 */

/// @title CatalogCosigns
/// @author COMPUTER DATA
/// @notice Proxy contract for Catalog Cosigns
contract CatalogCosigns is ERC1967Proxy {
    constructor(address _logic) ERC1967Proxy(_logic, "") {}
}
