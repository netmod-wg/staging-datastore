I_D = draft-lhotka-netmod-staging-datastore
REVNO = 00
DATE ?= $(shell date +%F)
MODULES = ietf-staging-datastore
SUBMODULES =
FIGURES =
EXAMPLE_BASE = example
EXAMPLE_TYPE = get-reply
baty = $(EXAMPLE_BASE)-$(EXAMPLE_TYPE)
EXAMPLE_INST =
PYANG_OPTS =
XML2RFC_OPTS = --text --v3 --no-dtd

# Paths for pyang
export PYANG_RNG_LIBDIR ?= /usr/share/yang/schema
export PYANG_XSLT_DIR ?= /usr/share/yang/xslt
export YANG_MODPATH ?= .:/usr/share/yang/modules/ietf:/usr/share/yang/modules/iana

yangsc = $(addsuffix .sc, $(yass) $(yams))
artworks = $(addsuffix .aw, $(FIGURES))
idrev = $(I_D)-$(REVNO)
yams = $(addsuffix .yang, $(MODULES))
yass = $(addsuffix .yang, $(SUBMODULES))
xsldir = .tools/xslt
xslpars = --stringparam date $(DATE) --stringparam i-d-name $(I_D) \
	  --stringparam i-d-rev $(REVNO)
schemas = $(baty).rng $(baty).sch $(baty).dsrl
y2dopts = -t $(EXAMPLE_TYPE) -b $(EXAMPLE_BASE)

.PHONY: all clean gittag rnc refs validate yang

all: $(idrev).txt # $(schemas) model.tree

refs: stdrefs.ent

yang: $(yass) $(yams)

$(idrev).xml: $(I_D).xml $(yangsc) $(artworks) figures.ent yang.ent
	@xsltproc --novalid $(xslpars) $(xsldir)/upd-i-d.xsl $< | \
	  xmllint --noent -o $@ -

$(idrev).txt: $(idrev).xml
	@xml2rfc $(XML2RFC_OPTS) $<

hello.xml: $(yass) $(yams) hello-external.ent
	@echo '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">' > $@
	@echo '<capabilities>' >> $@
	@echo '<capability>urn:ietf:params:netconf:base:1.1</capability>' >> $@
	@for m in $(yams); do \
	  capa=$$(pyang $(PYANG_OPTS) -f capability --capability-entity $$m); \
	  if [ "$$capa" != "" ]; then \
	    echo "<capability>$$capa</capability>" >> $@; \
	  fi \
	done
	@cat hello-external.ent >> $@
	@echo '</capabilities>' >> $@
	@echo '</hello>' >> $@

stdrefs.ent: $(I_D).xml
	xsltproc --novalid --output $@ $(xsldir)/get-refs.xsl $<

yang.ent: $(yass) $(yams)
	@echo '<!-- External entities for files with modules -->' > $@
	@for f in $^; do                                                 \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.sc\">" >> $@;          \
	done
ifneq ($EXAMPLE_INST,)
	@echo '<!ENTITY '"$(EXAMPLE_INST) SYSTEM \"$(EXAMPLE_INST).aw\">" >> $@
endif

figures.ent: $(FIGURES)
ifeq ($(FIGURES),)
	@touch $@
else
	@echo '<!-- External entities for files with figures -->' > $@; \
	for f in $^; do                                            \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;  \
	done
endif

%.yang: %.yinx
	@xsltproc --xinclude $(xsldir)/canonicalize.xsl $< | \
	  xsltproc --output $@ $(xslpars) $(xsldir)/yin2yang.xsl -

%.yang.sc: %.yang
	@pyang $(PYANG_OPTS) --ietf $<
	@echo '<sourcecode name="'$*@$(DATE)'.yang">' > $@
	@echo '<![CDATA[' >> $@
	@echo >> $@
	@cat $< >> $@
	@echo >> $@
	@echo ']]></sourcecode>' >> $@

%.aw: %
	@echo '<artwork><![CDATA[' > $@; \
	cat $< >> $@;                    \
	echo ']]></artwork>' >> $@

$(schemas): hello.xml
	yang2dsdl $(y2dopts) -L $<

%.rnc: %.rng
	trang -I rng -O rnc $< $@

rnc: $(baty).rnc

validate: $(EXAMPLE_INST) $(schemas)
	@yang2dsdl -j -s $(y2dopts) -v $<

model.tree: hello.xml
	pyang $(PYANG_OPTS) -f tree -o $@ -L $<

gittag: $(idrev).txt
	git tag -a -s -m "I-D revision $(REVNO)" "rev-$(REVNO)"
	git push --follow-tags

clean:
	@rm -rf *.rng *.rnc *.sch *.dsrl hello.xml model.tree \
	        $(yams) $(idrev).* $(yangsc) $(artworks) \
		figures.ent yang.ent
