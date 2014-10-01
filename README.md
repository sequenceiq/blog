This is the github repo serving the [SequenceIQ Blog](blog.sequenceiq.com).
Only the **gh-pages** branch is used, and only **jenkins** should push there.

# Work on blog-test

Don't commit into this repo at all, use the [sequenceiq/blog-test](https://github.com/sequenceiq/blog-test)
repo. Specifically it's **source** branch to push your markdown files. Then jenkis will automatically:

- generate the static blog
- create a new tag and [Release](https://github.com/sequenceiq/blog-test/releases)
  containing the **binary blog artifact**. Which is the tar gzipped gh-pages branch
- deploy it to [qa blog](http://qa.blog.sequenceiq.com/)

## Promote QA blog to LIVE

Once you are happy with the blog release as it looks on the
[qa blog](http://qa.blog.sequenceiq.com/), you have to use the **deploy blog to live**
jenkins job.
