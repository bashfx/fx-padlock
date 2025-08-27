
# STAKEHOLDER REQUIRED API FOR COMMANDS

FIRST verify that the options() function is using the BASHFX pattern for options, an example of this is in ref/patterns.
BashFX requires that option arguments be passed via --flag=value pattern and not --flag value pattern. Futher padlock should implement all 3 key aspects of BashFX options pattern.

## Ignition Key Concept details

The main ignite system exposed by the ignite command is for generating third party keys that can be shared with third parties, ai or automated systems. it works be generating a named key which the user provides, then the user must provide a passphrase that unlocks the ignition key. The ignition key when created is added as another recipient to the age encrypted files in the current repo (only). and record of third party ignition keys are added to an ignition manifest file in the namespace designated for the project in the XDG+ etc location.

(Repo) Ignition Key Concept: provides remote access to the age artifact via a passphrase. The passphrase unlocks the ignition key, and with the unlocked ignition key you can unlock the age repo. 

A Master/Backup ignition key works the same way by wrapping the master key with an age encryption layer, and can be restored via passphrase. (Note while ignition key concept is similar, this is a different concept part of the recover and master key unlock apis). 

General Ignition Concept. Ignition Keys require a passphrase to unlock, revealing a normal key inside. This key is used to unlock other things. Ignition keys can be distributed through this layered encryption mechanism and the age recipient pattern that allows you to add and remove recipients to an encrypted age file.

Ignition Key Heirarchy.


Given examples repos A,B,C, where (a,b,c) are assets of each, respectively

Xm => Master Ignition Key (Skull Key)
M => Master Key
R => Repo Key (Ra,Rb,Rc)
I => Repo Ignition Key (Ia,Ib,Ic)
D => Distributed Ignite Key (Da,Db,Dc)
S => Secrets (Sa,Sb,Sc)



> PassPhrase(Xm) => M
unlocking the skull key X reveals a copy of the master key M. We use this for a hard backup if the master key is ever lost, additonally the skull key can be stored almost anywhere without revealing the actual master key.

> UnlockRepo(A,Ra) => Sa
the padlock unlock command by default uses the repo's private key to unlock any of its secrets. 

> MasterUnlockRepo(M,Ra) => Sa
since the master key is an automatic recipient of the repo's encrypted assets, the master key can be used to unlock a repos secret as well. This is a backup/security measure that has to be explicitly called by the user if the automated githook does not work for some reason with the repos's default key.

Note: You cannot unlock a repo with the Skull key, you must first extract and install the master key again, and then call the MasterUnlock function directly.

> InginiteUnlockRepo(Ia,A) => Sa
the repo ignition key I gives a clean way to manage all third-party keys, if the ignition repo keys are ever rotated or invalidated, then all downstream distro ignition keys D will not be able to access the repo assets any longer, and would require a all new keys. The Repo ignition key can be rotated without having the upstream repo and master key rotated. This is a security feature of the ignition system.

> DistUnlockRepo( PassPhrase(Da),A ) => Ia
the distributed key D is strictly derived from the Repo Ignition Key I, and so D keys rely on the state of the I key to be valid. A third party can unlock a repo, by passing in their D key as an arugment to the `dist unlock` command and providing its passphrase, provided by the Repo owner. 


Master key is a recipient of all generated downstream keys, and can unlock any of them; one direction authority.
M => Ra => Ia => Da 

The Skull key is a hyper authority, in that it can unlock the master key, but does not have a direct path to the downstream keys without proper installation.

X => M
M => Ra => Ia => Da 

The Githooks for lock and unlock in padkey, rely strictly on the repo key stored on the owners original system. If the owner moves or uses other systems, they can create their own Distro key, to unlock repos, or copy their skull key in migrating/duplicating the padlock data onto the new system. There is a lot of flexibility and the Skull key and Master key are the control authoritiy keys.



## Missing Ignite API for owners generating third party keys

`padlock ignite` (list any created third-party/automation keys created and none if there isnt, returns 1 if no keys)

`padlock ignite new --name=name [--phrase=pass]` (this means, create a new thirdparty ignition key called `name` and output the keyfile to the current local directory `./ignition.name.key`, the --phrase is the passphrase needed to unlock the ignition key; the key itself and its md5 checksum should be added to the ignition manifest, as well the recipient id, the project repo key and the master key can both unlock any generated ignition key)

If there are no exiting D keys for the repo, then the initial I key must be generated in order to derive the subsequent D keys.

`padlock ignite revoke --name=name` (this removes a recipient from the repo's encrypted age artifact, and removes the recipient record from the ignition manifest).

`padlock ignite rotate` (this has the effect of destorying the I key and invalidaing the D keys completely, a new I key is derived from the Repo Key R)

`padlock ignite reset` (same effect as rotate except it clears all ignition assets from the repo, nuking the manifest and the I key, this is a heavy security command to remove access instantly)

`padlock ignite verify --path=path/to/ignite.key [--phrase=pass]` this double checks if the provided key is indeed a recepient of the repo secrets. if an optional pass phrase is passed, it can test unlocking the repo secret but wont actually execute (dryrun like). Return 0 if is valid.

`padlock ignite register --path=path/to/ignite.key [--phrase=pass]` this checks if the ignition key is known to the repo, via its ignition manifest, and if it isnt attempts to add it. Returns 0 if it exists or the add was succesful. Note that an 

(note ignition manigest = ignition keychain )

Note that all activities for `padlock ignite` are in fact on the D keys (distro), I keys are unknown to everyone accept the repo owner. Some commands require a valid I key from which the D key was derived in order to perform actions with the D key. If the D key cannot be validated with an I key, then it is not a valid recipient of the repo secret. 

`padlock ignite maybe` the maybe command checks if a D key claimed to be associated with I, but isnt, is possibly associated with M itself via another repo. 

However, in the chaos of the universe, a master key can still recognize a wayward D key. however if its not recognized by the I key for some R, then it perhaps belongs to a different repo, where M is the authority of the set of repos. D does not have priveleged access to subsets of repos owned by M unless they are explicitly granted. 

`padlock ignite integrity` the integrity command is to double check that the recorded I key, is in fact valid for the current R, and the current M. 

`padlock integrity` this top level integrity command checks that the current keys available to the repo are correctly associated to
M, R, and I. If all three keys are invalid, the repo is from a foreign system. Is the user trying to take ownership of the secret? Well sorry we dont have that feature yet, either get a D key, or declamp it on the foreign system first.
