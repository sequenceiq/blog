---
layout: post
title: "HDFS and java.nio.channels"
date: 2014-03-07 08:12:44 +0000
comments: true
published: true
categories: [HDFS, HDP2, RemoteBlockReader2, NameNode]
author: Janos Matyas
---
Many times there is a need to access files or interact with HDFS from Java applications or libraries. Hadoop has built in many tools in order to work or interact with HDFS - however in case you'd like to read into a content of a file remotely (e.g. retrieve the headers of a CSV/TSV file) random exceptions can occurs. One of these remote exceptions coming from the HDFS NameNode is a *java.io.IOException: File /user/abc/xyz/ could only be replicated to 0 nodes, instead of 1.*

Such an exception can be reproduced by the following code snippet: 

``` 
java BufferedInputStream bufferedInputStream

/**
 * For the sake of readability, try/cacth/finally blocks are removed 
 * Don't Say We Didn't Warn You
 */

FileSystem fs = FileSystem.get(configuration);
			Path filePath = getFilePath(dataPath);

BufferedInputStream bufferedInputStream = new BufferedInputStream(fs.open(filePath));
	listReader = new CsvListReader(new BufferedReader(new InputStreamReader(bufferedInputStream)),
				        CsvPreference.STANDARD_PREFERENCE);
				       
```

For the full stack trace click [here](https://gist.github.com/matyix/9386987).

{% gist 9386987 %}


*Note: actually all HDFS operations fail in case of the underlying input stream does not have a readable channel (check the java.nio.channels package. RemoteBlockReader2 needs channel based inputstreams to deal with direct buffers.*
 
Digging into details and checking the Hadoop 2.2 source code we find the followings: 

Through the`org.apache.hadoop.hdfs.BlockReaderFactory` you can get access to a BlockReader implementation like `org.apache.hadoop.hdfs.RemoteBlockReader2`, which it is responsible for reading a single block from a single datanode.

The blockreader is retrieved in the following way:

``` java

@SuppressWarnings("deprecation")
public static BlockReader newBlockReader(
                                     Conf conf,
 	                             Socket sock, String file,
                                     ExtendedBlock block, 
                                     Token<BlockTokenIdentifier> blockToken,
                                     long startOffset, long len,
                                     int bufferSize, boolean verifyChecksum,
                                     String clientName)
                                     throws IOException {
    if (conf.useLegacyBlockReader) {
      return RemoteBlockReader.newBlockReader(
          sock, file, block, blockToken, startOffset, len, bufferSize, verifyChecksum, clientName);
    } else {
      return RemoteBlockReader2.newBlockReader(
          sock, file, block, blockToken, startOffset, len, bufferSize, verifyChecksum, clientName);      
    }
  }
  
```

In order to avoid the exception and use the right version of the block reader, the followin property `conf.useLegacyBlockReader` should be TRUE.

Long story short, the configuration set of a job should be set to: `configuration.set("dfs.client.use.legacy.blockreader", "true")`. 

Unluckily in all cases when interacting with HDFS, and the underlying input stream does not have a readable channel, you can't use the *RemoteBlockReader2* implementation, but you have to fall back to the old legacy *RemoteBlockReader*.

Hope this helps,
SequenceIQ
