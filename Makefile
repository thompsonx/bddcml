DIRS = common_blocks bddcpp bddcmumps mumps_adaptive bddcml ppbddcml
##################################################################
# Targets
##################################################################

all: 
	@ \
        for i in ${DIRS}; \
        do \
          echo "Making $$i ..."; \
          (cd $$i && $(MAKE)); \
          echo ""; \
        done

clean: 
	@ \
        for i in ${DIRS}; \
        do \
          if [ -d $$i ]; \
          then \
            echo "Cleaning $$i ..."; \
            (cd $$i &&  $(MAKE) $@); \
          fi; \
        done

