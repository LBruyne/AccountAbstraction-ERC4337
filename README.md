# AccountAbstraction-ERC4337
An attempt to implement account-abstraction as described in ERC-4337 for personal interests.

The main purpose of this implementation is to understand and experience firsthand the key mechanisms and main execution processes of ERC-4337. It is missing at least the following parts, compared to the description in the ERC-4337 Specification:

- The implementation of `postOp`
- The `deadline` mechanism
- The `simulation` part of ERC-4337, as it only needs slight modification to the main execution logic to achieve this

However, I believe this is a good material for learning and understanding this proposal.

Keep in mind: this is a baby-implementation with tutorial purpose and it is not ready for practical uses. The codes are not reviewed or benched as well.

## Useful links

- ERC-4337 [Specification](https://eips.ethereum.org/EIPS/eip-4337).
- eth-infinitism's guide reference [implementation](https://github.com/eth-infinitism/account-abstraction) for ERC-4337.
- OKX's [implementation](https://github.com/okx/AccountAbstraction) which is complete, highly audited, and useable in practice.