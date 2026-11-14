# AppImages

Put AppImages in `~/Applications`. Within about 30 seconds they appear in the
app launcher with their icons, and disappear when the file is deleted. They
don't need to be executable. Only add AppImages you trust; they run with your
permissions.

AppImages run at scale 1 by default so they are not blurry or oversized;
change this in `package.nix`.
