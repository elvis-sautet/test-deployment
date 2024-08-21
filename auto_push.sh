#!/bin/bash

# Color codes for printing pretty messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Function to print error messages and exit
error_exit() {
  echo -e "${RED}$1${NC}"
  exit 1
}

# Ensure Git is initialized
if [ ! -d .git ]; then
  echo -e "${YELLOW}No Git repository found. Initializing...${NC}"
  git init || error_exit "Failed to initialize Git repository."

  echo -e "${YELLOW}Enter the remote repository URL (e.g., https://github.com/user/repo.git):${NC}"
  read -r remote_url
  git remote add origin "$remote_url" || error_exit "Failed to add remote."

  git checkout -b main || error_exit "Failed to create main branch."
  git add . || error_exit "Failed to stage files."
  git commit -m "Initial commit" || error_exit "Failed to commit changes."
  git push -u origin main || error_exit "Failed to push main branch to remote."
fi

# Function to ensure the working directory is clean
ensure_clean_working_directory() {
  if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Stashing local changes...${NC}"
    git stash || error_exit "Failed to stash changes."
    stash_needed=true
  else
    stash_needed=false
  fi
}

# Get the current branch
current_branch=$(git branch --show-current)

# Ensure we're on the correct branch before pushing
if [ "$current_branch" != "main" ]; then
  echo -e "${YELLOW}Pushing current branch ${GREEN}$current_branch${YELLOW}...${NC}"
  
  # Stage and commit changes if necessary
  if [ -n "$(git status --porcelain)" ]; then
    git add . || error_exit "Failed to stage changes."
    echo -e "${GREEN}Enter a conventional commit message (e.g., feat: add new feature, fix: correct a bug):${NC}"
    read -r commit_message
    git commit -m "$commit_message" || error_exit "Failed to commit changes."
  fi
  
  # Push the current branch
  git push origin "$current_branch" || error_exit "Failed to push changes to remote branch $current_branch."

  # Update the main branch
  ensure_clean_working_directory
  echo -e "${YELLOW}Switching to the main branch to pull recent changes...${NC}"
  git checkout main || error_exit "Failed to switch to main branch."
  git pull origin main || error_exit "Failed to pull changes from main branch."

  # Switch back to the original branch
  echo -e "${YELLOW}Switching back to branch ${GREEN}$current_branch${YELLOW}...${NC}"
  git checkout "$current_branch" || error_exit "Failed to switch back to branch $current_branch."

  # Apply stashed changes if needed
  if [ "$stash_needed" = true ]; then
    echo -e "${YELLOW}Applying stashed changes...${NC}"
    git stash pop || error_exit "Failed to apply stashed changes."
  fi
else
  echo -e "${YELLOW}On main branch, ensuring latest changes are pulled...${NC}"
  git pull origin main || error_exit "Failed to pull changes from main branch."
fi

# Check for version bump and tag if necessary
echo -e "${YELLOW}Checking for version bump...${NC}"
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)

if [ -z "$latest_tag" ]; then
  echo -e "${YELLOW}No existing tags found. Starting with v0.1.0${NC}"
  new_tag="v0.1.0"
else
  echo -e "${GREEN}Latest tag found: ${latest_tag}${NC}"
  if [[ "$commit_message" =~ ^feat ]]; then
    new_tag=$(echo $latest_tag | awk -F. -v OFS=. '{$2++; $3=0; print}')
  elif [[ "$commit_message" =~ ^fix ]]; then
    new_tag=$(echo $latest_tag | awk -F. -v OFS=. '{$3++; print}')
  else
    new_tag=$(echo $latest_tag | awk -F. -v OFS=. '{$3++; print}')
  fi
fi

# Tag the commit
echo -e "${YELLOW}Tagging commit with ${GREEN}${new_tag}${NC}"
git tag -a "$new_tag" -m "Release $new_tag" || error_exit "Failed to tag the commit."
git push origin "$new_tag" || error_exit "Failed to push the tag to remote."

echo -e "${GREEN}All done! Code is pushed and tagged as necessary.${NC}"
