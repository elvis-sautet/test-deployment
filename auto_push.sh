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

# Check if inside a Git repository, if not, initialize it
if [ ! -d .git ]; then
  echo -e "${YELLOW}No Git repository found. Initializing...${NC}"
  git init || error_exit "Failed to initialize Git repository."

  echo -e "${YELLOW}Enter the remote repository URL (e.g., https://github.com/user/repo.git):${NC}"
  read -r remote_url
  git remote add origin "$remote_url" || error_exit "Failed to add remote."

  # Set up the initial branch as 'main'
  echo -e "${YELLOW}Creating and checking out the main branch...${NC}"
  git checkout -b main || error_exit "Failed to create main branch."

  echo -e "${YELLOW}Staging initial files and committing...${NC}"
  git add . || error_exit "Failed to stage files."
  git commit -m "Initial commit" || error_exit "Failed to commit changes."

  echo -e "${YELLOW}Pushing the main branch to the remote repository...${NC}"
  git push -u origin main || error_exit "Failed to push main branch to remote."
else
  # Ensure 'main' branch is the default branch
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "main" ]; then
    if ! git show-ref --verify --quiet refs/heads/main; then
      echo -e "${YELLOW}Creating and switching to the main branch...${NC}"
      git checkout -b main || error_exit "Failed to create and switch to main branch."
      git push -u origin main || error_exit "Failed to push main branch to remote."
    else
      echo -e "${YELLOW}Switching to the main branch...${NC}"
      git checkout main || error_exit "Failed to switch to main branch."
    fi
  fi
fi

# Fetch latest changes from the remote repository
echo -e "${YELLOW}Fetching latest changes from origin...${NC}"
git fetch origin || error_exit "Failed to fetch changes from origin."

# Check if the working directory is clean
if [ -n "$(git status --porcelain)" ]; then
  echo -e "${YELLOW}Staging all changes...${NC}"
  git add . || error_exit "Failed to stage changes."

  # Prompt user for a conventional commit message
  echo -e "${GREEN}Enter a conventional commit message (e.g., feat: add new feature, fix: correct a bug):${NC}"
  read -r commit_message

  # Commit the changes with the conventional commit message
  git commit -m "$commit_message" || error_exit "Failed to commit changes."

  # Push to the current branch
  echo -e "${YELLOW}Pushing to branch ${GREEN}$current_branch${YELLOW}...${NC}"
  git push origin "$current_branch" || error_exit "Failed to push changes to remote."
else
  echo -e "${GREEN}No changes detected. Working directory is clean.${NC}"
fi

# Check for version bump and tag if necessary
echo -e "${YELLOW}Checking for version bump...${NC}"
# Fetch latest tag
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)

if [ -z "$latest_tag" ]; then
  echo -e "${YELLOW}No existing tags found. Starting with v0.1.0${NC}"
  new_tag="v0.1.0"
else
  echo -e "${GREEN}Latest tag found: ${latest_tag}${NC}"

  # Assuming conventional commit versioning bump logic
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
