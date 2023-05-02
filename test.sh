IS_MASTER_LOCAL=true
IS_MINION_LOCAL=true
if ${IS_MASTER_LOCAL} && ${IS_MINION_LOCAL}; then
    echo "Skippping the script "
    exit 0 
fi