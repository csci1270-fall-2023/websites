# CSCI 1270 - Website

## Getting Started

This website is built using [Goo](https://github.com/n-young/goo). Ensure that you have Goo installed to build it.

Unless you REALLY know what you are doing, use the Makefile to build. There are two main commands; `build` and `build-ta`. You should always run `make build` before pushing; what this does is build the student-facing side of the website, stripping all of the solutions from homeworks with it. If you want to view the solutions in HTML, run `make build-ta` and view the solutions in the `build-ta/` directory. If you'd like to serve this repository locally, run one of the `serve-*` targets; they will run a server at port 3000.

To manually build the website, run `go get github.com/n-young/goo`, then `goo build site.yaml`. The site wil be exported to the `build/` directory. See the Goo documentation for information on how to use it.


## File Structure

Goo is a non-opinionated static site generator, but we follow a specific convention to help reduce confusion. Moreover, integration with multiple build types, snipping, and pdf generation make this slightly confusion; this section explains the file structure to the best of my ability.

The `./` directory contains a Makefile with targets to build a student-facing version of the website with solutions removed, and a ta-facing version with solutions included. See below for instructions on releasing solutions to students. It also contains two `site.yaml` files, which is how Goo determines what to build and how. These files are identical except for where they pull data; the student version pulls snipped data. **Building the `site-ta.yaml` file will embed solutions in the HTML and PDFs - be careful not to publish this!**

The `./views` directory contains HTML templates in Goo format. Nothing interesting here, read Goo documentation to get a sense of how they work.

The `./static` directory is where web content lives; all of these files will be directly copied into the build. We have css, static files, generated files, images, and js.

The `./src` folder is where Goo pulls information to build the website from. The `data` subfolder is where tabular information is stored, i.e. lectures dates. These are embeded into the home page according to Goo's templating logic. The `docs` subfolder is where page content is stored, i.e. handouts and guides.

The `./build` and `./build-ta` directories are where the website builds are served from. The former must not be .gitignore'd since it needs to be in the repository for Netlify to work. The latter should be .gitignore'd to avoid leaking info.

The `./scripts` directory contains scripts used to snip solutions out of homework files and generate PDF files from Markdown. These are called from the Makefile directly.

The `./documents` directory is not related to the website, it's simply where we put vital documents' build source, like the missive and the collaboration policy.


## Documents

Each document follows the same structure. At the top, we have front matter which looks like:

```md
---
title: Hash + Join Algorithms
name: hash+join_algorithms
due: November 1
draft: "true"
---
```

The `title` field will be the HTML title when compiled. The `name` field must match up with the file name. The `due` field indicates on the PDF when the assignment is due. The `draft` field is important; when it is `"true"` (note, this is the *string* `"true"`, not the *boolean* `true`), the document will not be built, except for when running `goo` with the `--draft` field (all od the `-ta` Makefile targets do this). When is it `"false"` or not included, the document will be built.

There are also tags that look like the following:

```
<!-- SOLUTION {{{ -->
Some hidden content
<!-- SOLUTION }}} -->
```

Anything between these tags will be hidden from student view. The `-ta` Makefile targets don't snip the solution content, meaning that you can view solutions in HTML that way.

Otherwise, documents support all regular markdown, inline and block LaTeX, code highlighting, :joy:-style emojis, and more; see the Goo documentation for more.


## Releasing Homework Solutions

To release homework solutions, generate the TA version of the website, grab the PDF solution for the assignment you'd like to release solutions for, encrypt it with a long (20 chars or longer) password (we used [SmallPDF](https://smallpdf.com/protect-pdf) for this), upload it to Drive, and send the link and password on Campuswire.
