#################################
# install ONLY by ejudge user   #
#################################

INSTALL_DIR=/home/ejudge/inst-ejudge-scrips

EJ_WRAPPER=ejudge_wrapper.sh
EJ_DESC_GENERATOR=generate_description.py
EJ_PROBLEMS_UPLOADER=ej-problems-uploader.py
EJ_RESTART=restart-ej-contest.sh
EJ_TEST_NORMALIZER=tests_normalizer.pl

user=$(shell whoami)

install:
ifneq (${user}, ejudge)
	@ echo "only ejudge user can do this!"
	@ exit 1
else
endif
	@ echo "install to directory: ${INSTALL_DIR}"
	@ mkdir -p ${INSTALL_DIR}
	@ cp -v ${EJ_WRAPPER} ${INSTALL_DIR}
	@ cp -v ${EJ_DESC_GENERATOR} ${INSTALL_DIR}
	@ cp -v ${EJ_PROBLEMS_UPLOADER} ${INSTALL_DIR}
	@ cp -v ${EJ_RESTART} ${INSTALL_DIR}
	@ cp -v ${EJ_TEST_NORMALIZER} ${INSTALL_DIR}
