Note that License.txt applies to the source code include in Classes, but does
not include the Classes/LZMASDK files which are in the public domain. The
video and audio resources were downloaded off the internet, no claim of
ownership or license is made on these files.

A developer could simply include the MOVS/*.mov files as iOS project resources,
but it is a lot better to use the 7zip library to compress the video data.  
The 7zip library compresses video data much better than gzip, libz, or bzip2.
In addition, runtime performance can be improved by converting the .mov files
to .mvid video optimized for iOS. These instructions shows how to use the
qtaniframes executable from the QTFileParser example.

Commands to create RyuMvids.7z Archive:

Each .mvid file is larger than the corresponding .mov file, but smaller
once compressed with 7zip. In this simple example, compressing 4 movies
with 7zip saves about 60K. If many video files were included in the app
then the space savings would be much larger.

RyuMovs.zip : 263041 bytes (263 K)
RyuMovs.7z  : 215821 bytes (216 K)
RyuMvids.7z : 198946 bytes (199 K)

$ qtaniframes -mvid RyuFireball.mov
wrote RyuFireball.mvid

$ qtaniframes -mvid RyuHighKick.mov
wrote RyuHighKick.mvid

$ qtaniframes -mvid RyuStance.mov
wrote RyuStance.mvid

$ qtaniframes -mvid RyuStrongPunch.mov 
wrote RyuStrongPunch.mvid

$ 7za a -mx=9 RyuMvids.7z RyuFireball.mvid RyuHighKick.mvid RyuStance.mvid RyuStrongPunch.mvid
