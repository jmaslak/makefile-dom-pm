# NAME

Makefile::DOM - Simple DOM parser for Makefiles

Table of Contents
=================

* [NAME](#name)
* [VERSION](#version)
* [DESCRIPTION](#description)
* [Structure of the DOM](#structure-of-the-dom)
* [OPERATIONS FOR MDOM TREES](#operations-for-mdom-trees)
* [BUGS AND TODO](#bugs-and-todo)
* [SOURCE REPOSITORY](#source-repository)
* [AUTHOR](#author)
* [COPYRIGHT](#copyright)
* [SEE ALSO](#see-also)

# VERSION

This document describes Makefile::DOM 0.008 released on 18 November 2014.

# DESCRIPTION

This library can serve as an advanced lexer for (GNU) makefiles. It parses makefiles as "documents" and the parsing is lossless. The results are data structures similar to DOM trees. The DOM trees hold every single bit of the information in the original input files, including white spaces, blank lines and makefile comments. That means it's possible to reproduce the original makefiles from the DOM trees. In addition, each node of the DOM trees is modifiable and so is the whole tree, just like the [PPI](https://metacpan.org/pod/PPI) module used for Perl source parsing and the [HTML::TreeBuilder](https://metacpan.org/pod/HTML::TreeBuilder) module used for parsing HTML source.

If you're looking for a true GNU make parser that generates an AST, please see [Makefile::Parser::GmakeDB](https://metacpan.org/pod/Makefile::Parser::GmakeDB) instead.

The interface of `Makefile::DOM` mimics the API design of [PPI](https://metacpan.org/pod/PPI). In fact, I've directly stolen the source code and POD documentation of [PPI::Node](https://metacpan.org/pod/PPI::Node), [PPI::Element](https://metacpan.org/pod/PPI::Element), and [PPI::Dumper](https://metacpan.org/pod/PPI::Dumper), with the full permission from the author of [PPI](https://metacpan.org/pod/PPI), Adam Kennedy.

`Makefile::DOM` tries to be independent of specific makefile's syntax. The same set of DOM node types is supposed to get shared by different makefile DOM generators. For example, [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake) parses GNU makefiles and returns an instance of [MDOM::Document](https://metacpan.org/pod/MDOM::Document), i.e., the root of the DOM tree while the NMAKE makefile lexer in the future, `MDOM::Document::Nmake`, also returns instances of the [MDOM::Document](https://metacpan.org/pod/MDOM::Document) class. Later, I'll also consider adding support for dmake and bsdmake.

# Structure of the DOM

Makefile DOM (MDOM) is a structured set of a series of data types. They provide a flexible document model conforming to the makefile syntax. Below is a complete list of the 19 MDOM classes in the current implementation where the indentation indicates the class inheritance relationships.

    MDOM::Element
        MDOM::Node
            MDOM::Unknown
            MDOM::Assignment
            MDOM::Command
            MDOM::Directive
            MDOM::Document
                MDOM::Document::Gmake
            MDOM::Rule
                MDOM::Rule::Simple
                MDOM::Rule::StaticPattern
        MDOM::Token
            MDOM::Token::Bare
            MDOM::Token::Comment
            MDOM::Token::Continuation
            MDOM::Token::Interpolation
            MDOM::Token::Modifier
            MDOM::Token::Separator
            MDOM::Token::Whitespace

It's not hard to see that all of the MDOM classes inherit from the [MDOM::Element](https://metacpan.org/pod/MDOM::Element) class. [MDOM::Token](https://metacpan.org/pod/MDOM::Token) and [MDOM::Node](https://metacpan.org/pod/MDOM::Node) are its direct children. The former represents a string token which is atomic from the perspective of the lexer while the latter represents a structured node, which usually has one or more children, and serves as the container for other [DOM::Element](https://metacpan.org/pod/DOM::Element) objects.

Next we'll show a few examples to demonstrate how to map DOM trees to particular makefiles.

- Case 1

    Consider the following simple "hello, world" makefile:

        all : ; echo "hello, world"

    We can use the [MDOM::Dumper](https://metacpan.org/pod/MDOM::Dumper) class provided by [Makefile::DOM](https://metacpan.org/pod/Makefile::DOM) to dump out the internal structure of its corresponding MDOM tree:

        MDOM::Document::Gmake
          MDOM::Rule::Simple
            MDOM::Token::Bare         'all'
            MDOM::Token::Whitespace   ' '
            MDOM::Token::Separator    ':'
            MDOM::Token::Whitespace   ' '
            MDOM::Command
              MDOM::Token::Separator    ';'
              MDOM::Token::Whitespace   ' '
              MDOM::Token::Bare         'echo "hello, world"'
              MDOM::Token::Whitespace   '\n'

    In this example, separators `:` and `;` are all instances of the [MDOM::Token::Separator](https://metacpan.org/pod/MDOM::Token::Separator) class while spaces and new line characters are all represented as [MDOM::Token::Whitespace](https://metacpan.org/pod/MDOM::Token::Whitespace). The other two leaf nodes, `all` and `echo "hello, world"`, both belong to [MDOM::Token::Bare](https://metacpan.org/pod/MDOM::Token::Bare).

    It's worth mentioning that the space characters in the rule command `echo "hello, world"` were not represented as [MDOM::Token::Whitespace](https://metacpan.org/pod/MDOM::Token::Whitespace). That's because in makefiles the spaces in commands do not make any sense to `make` in syntax; those spaces are usually sent to shell programs verbatim. Therefore, the DOM parser does not try to recognize those spaces specifially so as to reduce memory use and the number of nodes. However, leading spaces and trailing new lines will still be recognized as [MDOM::Token::Whitespace](https://metacpan.org/pod/MDOM::Token::Whitespace).

    At a higher level there is a [MDOM::Rule::Simple](https://metacpan.org/pod/MDOM::Rule::Simple) instance holding several `Token` and one [MDOM::Command](https://metacpan.org/pod/MDOM::Command). At the highest level there is the root node of the whole DOM tree, i.e., an instance of [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake).

- Case 2

    Below is a relatively complex example:

        a: foo.c  bar.h $(baz) # hello!
            @echo ...

    Its corresponding DOM structure is

        MDOM::Document::Gmake
          MDOM::Rule::Simple
            MDOM::Token::Bare         'a'
            MDOM::Token::Separator    ':'
            MDOM::Token::Whitespace   ' '
            MDOM::Token::Bare         'foo.c'
            MDOM::Token::Whitespace   '  '
            MDOM::Token::Bare         'bar.h'
            MDOM::Token::Whitespace   '\t'
            MDOM::Token::Interpolation   '$(baz)'
            MDOM::Token::Whitespace      ' '
            MDOM::Token::Comment         '# hello!'
            MDOM::Token::Whitespace      '\n'
          MDOM::Command
            MDOM::Token::Separator    '\t'
            MDOM::Token::Modifier     '@'
            MDOM::Token::Bare         'echo ...'
            MDOM::Token::Whitespace   '\n'

    Compared to the previous example there are several new node types.

    The variable interpolation `$(baz)` on the first line of the makefile corresponds to a [MDOM::Token::Interpolation](https://metacpan.org/pod/MDOM::Token::Interpolation) node in its MDOM tree. Similarly, the comment `# hello` corresponds to a [MDOM::Token::Comment](https://metacpan.org/pod/MDOM::Token::Comment) node.

    On the second line of the make file the rule command indented by a tab character is represented by a [MDOM::Command](https://metacpan.org/pod/MDOM::Command) object. Its first child node (or its first element) is also an [MDOM::Token::Seperator](https://metacpan.org/pod/MDOM::Token::Seperator) instance corresponding to that tab. The command modifier `@` follows the `Separator` immediately, which is of type [MDOM::Token::Modifier](https://metacpan.org/pod/MDOM::Token::Modifier).

- Case 3

    Now let's study a sample makefile with various global structures:

        a: b
        foo = bar
            # hello!

    Here on the top level there are three language structures: one rule "`a: b`", one assignment statement "foo = bar", and one comment `# hello!`.

    Its MDOM tree is shown below:

        MDOM::Document::Gmake
          MDOM::Rule::Simple
            MDOM::Token::Bare                  'a'
            MDOM::Token::Separator            ':'
            MDOM::Token::Whitespace           ' '
            MDOM::Token::Bare                   'b'
            MDOM::Token::Whitespace           '\n'
          MDOM::Assignment
            MDOM::Token::Bare                  'foo'
            MDOM::Token::Whitespace           ' '
            MDOM::Token::Separator            '='
            MDOM::Token::Whitespace           ' '
            MDOM::Token::Bare                  'bar'
            MDOM::Token::Whitespace           '\n'
          MDOM::Token::Whitespace            '\t'
          MDOM::Token::Comment               '# hello!'
          MDOM::Token::Whitespace            '\n'

    We can see that below the root node [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake), there are [MDOM::Rule::Simple](https://metacpan.org/pod/MDOM::Rule::Simple), [MDOM::Assignment](https://metacpan.org/pod/MDOM::Assignment), and [MDOM::Comment](https://metacpan.org/pod/MDOM::Comment) three elements, as well as two [MDOM::Token::Whitespace](https://metacpan.org/pod/MDOM::Token::Whitespace) objects.

It can be observed from the examples above that the MDOM representation for the makefile's lexical elements is rather loose. It only provides very limited structural representation instead of making a bad guess.

[Back to TOC](#table-of-contents)

# OPERATIONS FOR MDOM TREES

Generating an MDOM tree from a GNU makefile only requires two lines of Perl code:

    use MDOM::Document::Gmake;
    my $dom = MDOM::Document::Gmake->new('Makefile');

If the makefile source code being parsed is already stored in a Perl variable, say, `$var`, then we can construct an MDOM via the following code:

    my $dom = MDOM::Document::Gmake->new(\$var);

Here `$dom` is a reference to the root of the MDOM tree and its type is [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake), which is also an instance of the [MDOM::Node](https://metacpan.org/pod/MDOM::Node) class.

As mentioned above, `MDOM::Node` is the container for other [MDOM::Element](https://metacpan.org/pod/MDOM::Element) instances. So we can retrieve an element node's value via its `child` method:

    $node = $dom->child(3);
    # or $node = $dom->elements(0);

We may also use the `elements` method to obtain the values of each of the nodes:

    @elems = $dom->elements;

For every MDOM node its corresponding makefile source can be generated by invoking its `content` method.

[Back to TOC](#table-of-contents)

# BUGS AND TODO

The current implementation of the [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake) lexer is
based on a hand-written state machine. Although the efficiency of the
engine is not bad, the code is rather complicated and messy, which
hurts both extensibility and maintanabilty. So it's expected to
rewrite the parser using some grammatical tools like the Perl 6 regex
engine [Pugs::Compiler::Rule](https://metacpan.org/pod/Pugs::Compiler::Rule) or a yacc-style one like
[Parse::Yapp](https://metacpan.org/pod/Parse::Yapp).

[Back to TOC](#table-of-contents)

# SOURCE REPOSITORY

You can always get the latest source code of this module from its GitHub repository:

[http://github.com/agentzh/makefile-dom-pm](http://github.com/agentzh/makefile-dom-pm)

If you want a commit bit, please let me know.

[Back to TOC](#table-of-contents)

# AUTHOR

Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>

[Back to TOC](#table-of-contents)

# COPYRIGHT

Copyright 2006-2014 by Yichun "agentzh" Zhang (章亦春).

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

[Back to TOC](#table-of-contents)

# SEE ALSO

[MDOM::Document](https://metacpan.org/pod/MDOM::Document), [MDOM::Document::Gmake](https://metacpan.org/pod/MDOM::Document::Gmake), [PPI](https://metacpan.org/pod/PPI), [Makefile::Parser::GmakeDB](https://metacpan.org/pod/Makefile::Parser::GmakeDB), [makesimple](https://metacpan.org/pod/makesimple).

[Back to TOC](#table-of-contents)

