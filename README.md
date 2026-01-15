# TP Blockchain – Système de vote décentralisé

Projet réalisé dans le cadre du TP Blockchain avec **Solidity**, **Foundry** et **OpenZeppelin**.

Ce projet implémente un système de vote décentralisé sécurisé, intégrant un workflow strict, une gestion avancée des rôles et l’utilisation de NFT pour garantir l’unicité des votes.

---

## Fonctionnalités

- Enregistrement de candidats
- Workflow contrôlé avec 4 phases :
  - `REGISTER_CANDIDATES`
  - `FOUND_CANDIDATES`
  - `VOTE`
  - `COMPLETED`
- Gestion des rôles via OpenZeppelin `AccessControl` :
  - `ADMIN_ROLE` : gestion du workflow et des rôles
  - `FOUNDER_ROLE` : financement des candidats
  - `WITHDRAWER_ROLE` : retrait des fonds du contrat
- Vote possible uniquement **1 heure après** l’ouverture de la phase `VOTE`
- NFT de vote (`ERC721`) :
  - 1 NFT est minté à chaque votant
  - un wallet possédant déjà un NFT de vote ne peut plus voter
- Désignation automatique du vainqueur
- Retrait des fonds possible uniquement lorsque le workflow est terminé

---

## Tests unitaires

Les tests sont réalisés avec **Foundry**.

```bash
forge test -vv
```

---

Déploiement sur le testnet Sepolia

Les smart contracts ont été déployés sur le réseau Ethereum Sepolia (chainId: 11155111) à l’aide d’un script Foundry.

---

Contrats déployés
VoteNFT (ERC721)

    Adresse :
    0xDB0354d80B9F31058019262f76D4dcC3e3EC0CcE

    Etherscan :
    https://sepolia.etherscan.io/address/0xDB0354d80B9F31058019262f76D4dcC3e3EC0CcE

SimpleVotingSystem

    Adresse :
    0xf43a605fB4eA0Cd4C72346859a7bEC18f8A944e6

    Etherscan :
    https://sepolia.etherscan.io/address/0xf43a605fB4eA0Cd4C72346859a7bEC18f8A944e6

---

Transactions Sepolia (preuves on-chain)
Déploiement du contrat VoteNFT

    Transaction hash :
    0xb6e138799144656a072cda3fa6836749d0709287c8111cb29e4570db48b310af

    Lien Etherscan :
    https://sepolia.etherscan.io/tx/0xb6e138799144656a072cda3fa6836749d0709287c8111cb29e4570db48b310af

---

Déploiement du contrat SimpleVotingSystem

    Transaction hash :
    0x271d298e2e40e87a1d4a2d4df490af2e887aecf3342eade6ffb1acdf5c5e610a

    Lien Etherscan :
    https://sepolia.etherscan.io/tx/0x271d298e2e40e87a1d4a2d4df490af2e887aecf3342eade6ffb1acdf5c5e610a

---

Déploiement avec Foundry

```bash
forge script script/Deploy.s.sol:Deploy \
 --rpc-url $SEPOLIA_RPC_URL \
 --private-key $SEPOLIA_PRIVATE_KEY \
 --broadcast
```

---

Auteur

    Nom : Jonathan Boulay
