#
# Add any required ${PATH} overrides to this file, which is sourced from /etc/profile.
#
# This file was deployed with the cluster role from the league-of-robots repo;
# Do not modify in place, but change the code and redeploy with Ansible instead.
#
pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}

pathmunge /usr/local/bin after

unset -f pathmunge